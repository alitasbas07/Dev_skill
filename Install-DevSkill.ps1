[CmdletBinding()]
param(
    [string]$SourcePath,
    [string]$Repository = "alitasbas07/Dev_skill",
    [string]$Ref = "main",
    [string]$CanonicalRoot = (Join-Path $HOME ".agents\skills"),
    [string]$ClaudeRoot = (Join-Path $HOME ".claude\skills"),
    [string]$CodexRoot = $(if ($env:CODEX_HOME) { Join-Path $env:CODEX_HOME "skills" } else { Join-Path $HOME ".codex\skills" })
)

$ErrorActionPreference = "Stop"
$skillNames = @("dev-skill-orchestrator", "dev-skill-developer", "dev-skill-tester", "dev-skill-reviewer")
$temporaryDirectory = $null

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

try {
    foreach ($root in @($CanonicalRoot, $ClaudeRoot, $CodexRoot)) {
        Assert-SafeRoot -Path $root
        New-Item -ItemType Directory -Force -Path $root | Out-Null
    }

    if ($SourcePath) {
        $sourceRoot = [IO.Path]::GetFullPath($SourcePath)
    } else {
        $temporaryDirectory = Join-Path ([IO.Path]::GetTempPath()) ("DevSkill-" + [guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $temporaryDirectory | Out-Null
        $archivePath = Join-Path $temporaryDirectory "source.zip"
        Invoke-WebRequest -Uri "https://codeload.github.com/$Repository/zip/$Ref" -OutFile $archivePath -UseBasicParsing
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
        $canonicalSkill = Join-Path $CanonicalRoot $skillName
        Move-ExistingToBackup -Path $canonicalSkill -BackupRoot (Join-Path $backupBase "agents")
        Copy-Item -LiteralPath $sourceSkill -Destination $canonicalSkill -Recurse

        foreach ($client in @(@{ Root = $ClaudeRoot; Name = "claude" }, @{ Root = $CodexRoot; Name = "codex" })) {
            $clientSkill = Join-Path $client.Root $skillName
            Move-ExistingToBackup -Path $clientSkill -BackupRoot (Join-Path $backupBase $client.Name)
            New-SkillLink -Target $canonicalSkill -Link $clientSkill
        }
    }

    Write-Host "Dev_skill installed successfully." -ForegroundColor Green
    Write-Host "Canonical: $CanonicalRoot"
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

