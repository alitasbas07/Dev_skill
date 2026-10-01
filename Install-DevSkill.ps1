[CmdletBinding()]
param(
    [string]$SourcePath,
    [string]$Repository = "alitasbas07/Dev_skill",
    [string]$Ref = "main",
    [ValidateSet("Ask", "Global", "Project")]
    [string]$Scope = "Ask",
    [string]$ProjectPath,
    [string]$CanonicalRoot = (Join-Path $HOME ".agents\skills"),
    [string]$ClaudeRoot = (Join-Path $HOME ".claude\skills"),
    [string]$CodexRoot = $(if ($env:CODEX_HOME) { Join-Path $env:CODEX_HOME "skills" } else { Join-Path $HOME ".codex\skills" })
)

$ErrorActionPreference = "Stop"
$skillNames = @("dev-skill-orchestrator", "dev-skill-developer", "dev-skill-tester", "dev-skill-reviewer")
$temporaryDirectory = $null

# Resolve relative source paths before a folder picker can change the process directory.
if ($SourcePath) {
    $SourcePath = (Resolve-Path -LiteralPath $SourcePath -ErrorAction Stop).Path
}

function Assert-SafeRoot {
    param([Parameter(Mandatory)][string]$Path)
    $resolvedHome = [IO.Path]::GetFullPath($HOME).TrimEnd('\', '/')
    $resolvedPath = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    if ($resolvedPath -eq $resolvedHome -or $resolvedPath.Length -le 3) { throw "Unsafe install root: $resolvedPath" }
}

function Move-ExistingToBackup {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$BackupRoot)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
    $destination = Join-Path $BackupRoot (Split-Path -Leaf $Path)
    if (Test-Path -LiteralPath $destination) { throw "Backup target already exists: $destination" }
    Move-Item -LiteralPath $Path -Destination $destination
}

function New-SkillLink {
    param([Parameter(Mandatory)][string]$Target, [Parameter(Mandatory)][string]$Link)
    if ($IsWindows -or $env:OS -eq "Windows_NT") {
        New-Item -ItemType Junction -Path $Link -Target $Target | Out-Null
    } else {
        New-Item -ItemType SymbolicLink -Path $Link -Target $Target | Out-Null
    }
}

function Select-ProjectFolder {
    param([string]$InitialDirectory)

    if (-not ($IsWindows -or $env:OS -eq "Windows_NT")) {
        return Read-Host "Enter the full project directory path"
    }

    try {
        Add-Type -AssemblyName System.Windows.Forms
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title = "Select the project where Dev_skill will be installed"
        $dialog.Filter = "Project folder|*.folder"
        $dialog.FileName = "Select this folder"
        $dialog.CheckFileExists = $false
        $dialog.CheckPathExists = $true
        $dialog.ValidateNames = $false
        $dialog.Multiselect = $false
        $dialog.RestoreDirectory = $true
        if ($InitialDirectory -and (Test-Path -LiteralPath $InitialDirectory -PathType Container)) {
            $dialog.InitialDirectory = $InitialDirectory
        }
        $owner = New-Object System.Windows.Forms.Form
        $owner.TopMost = $true
        $owner.ShowInTaskbar = $false
        $result = $dialog.ShowDialog($owner)
        $selectedPath = if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            Split-Path -Parent $dialog.FileName
        } else {
            $null
        }
        $owner.Dispose()
        $dialog.Dispose()
        if ($result -ne [System.Windows.Forms.DialogResult]::OK -or -not $selectedPath) {
            throw "Project selection was cancelled."
        }
        return $selectedPath
    } catch {
        Write-Warning "The folder picker could not be opened: $($_.Exception.Message)"
        return Read-Host "Enter the full project directory path"
    }
}

try {
    if ($Scope -eq "Ask") {
        Write-Host "Select installation scope:"
        Write-Host "  1) Global - available in every project"
        Write-Host "  2) Project - installed only in a selected project"
        do {
            $selection = Read-Host "Enter 1 or 2"
        } until ($selection -in @("1", "2"))
        $Scope = if ($selection -eq "1") { "Global" } else { "Project" }
    }

    if ($Scope -eq "Project") {
        if (-not $ProjectPath) {
            $initialDirectory = if ($SourcePath) { Split-Path -Parent $SourcePath } else { (Get-Location).Path }
            $ProjectPath = Select-ProjectFolder -InitialDirectory $initialDirectory
        }
        if (-not $ProjectPath -or -not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
            throw "Project directory does not exist: $ProjectPath"
        }
        $ProjectPath = [IO.Path]::GetFullPath($ProjectPath)
        $CanonicalRoot = Join-Path $ProjectPath ".agents\skills"
        $ClaudeRoot = Join-Path $ProjectPath ".claude\skills"
        $CodexRoot = Join-Path $ProjectPath ".codex\skills"
    }

    foreach ($root in @($CanonicalRoot, $ClaudeRoot, $CodexRoot)) {
        Assert-SafeRoot -Path $root
        New-Item -ItemType Directory -Force -Path $root | Out-Null
    }

    if ($SourcePath) {
        $sourceRoot = $SourcePath
    } else {
        $ghCommand = Get-Command gh -ErrorAction SilentlyContinue
        if (-not $ghCommand) {
            throw "GitHub CLI (gh) is required to install from the private repository."
        }
        $githubToken = (& gh auth token 2>$null).Trim()
        if ($LASTEXITCODE -ne 0 -or -not $githubToken) {
            throw "GitHub authentication is required. Run: gh auth login"
        }
        $temporaryDirectory = Join-Path ([IO.Path]::GetTempPath()) ("DevSkill-" + [guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $temporaryDirectory | Out-Null
        $archivePath = Join-Path $temporaryDirectory "source.zip"
        $headers = @{
            Authorization = "Bearer $githubToken"
            Accept = "application/vnd.github+json"
            "X-GitHub-Api-Version" = "2022-11-28"
        }
        Invoke-WebRequest -Uri "https://api.github.com/repos/$Repository/zipball/$Ref" -Headers $headers -OutFile $archivePath -UseBasicParsing
        $githubToken = $null
        Expand-Archive -LiteralPath $archivePath -DestinationPath $temporaryDirectory
        $sourceRoot = Get-ChildItem -LiteralPath $temporaryDirectory -Directory |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "skills") } |
            Select-Object -First 1 -ExpandProperty FullName
    }

    if (-not $sourceRoot -or -not (Test-Path -LiteralPath (Join-Path $sourceRoot "skills"))) {
        throw "The source does not contain a skills directory."
    }

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupBase = Join-Path $HOME ".dev-skill-backups\$stamp"
    foreach ($skillName in $skillNames) {
        $sourceSkill = Join-Path (Join-Path $sourceRoot "skills") $skillName
        if (-not (Test-Path -LiteralPath (Join-Path $sourceSkill "SKILL.md"))) { throw "Missing skill: $skillName" }

        if ($Scope -eq "Global") {
            $canonicalSkill = Join-Path $CanonicalRoot $skillName
            Move-ExistingToBackup -Path $canonicalSkill -BackupRoot (Join-Path $backupBase "agents")
            Copy-Item -LiteralPath $sourceSkill -Destination $canonicalSkill -Recurse
            foreach ($client in @(@{ Root = $ClaudeRoot; Name = "claude" }, @{ Root = $CodexRoot; Name = "codex" })) {
                $clientSkill = Join-Path $client.Root $skillName
                Move-ExistingToBackup -Path $clientSkill -BackupRoot (Join-Path $backupBase $client.Name)
                New-SkillLink -Target $canonicalSkill -Link $clientSkill
            }
        } else {
            foreach ($client in @(
                @{ Root = $CanonicalRoot; Name = "agents" },
                @{ Root = $ClaudeRoot; Name = "claude" },
                @{ Root = $CodexRoot; Name = "codex" }
            )) {
                $clientSkill = Join-Path $client.Root $skillName
                Move-ExistingToBackup -Path $clientSkill -BackupRoot (Join-Path $backupBase ("project-" + $client.Name))
                Copy-Item -LiteralPath $sourceSkill -Destination $clientSkill -Recurse
            }
        }
    }

    Write-Host "Dev_skill installed successfully." -ForegroundColor Green
    Write-Host "Scope: $Scope"
    if ($Scope -eq "Project") { Write-Host "Project: $ProjectPath" }
    Write-Host "Skills root: $CanonicalRoot"
    Write-Host "Restart Claude Code, Codex and Orca sessions to reload skills."
} finally {
    if ($temporaryDirectory -and (Test-Path -LiteralPath $temporaryDirectory)) {
        $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        $resolvedTemporary = [IO.Path]::GetFullPath($temporaryDirectory)
        if ($resolvedTemporary.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedTemporary -Recurse -Force
        }
    }
}
