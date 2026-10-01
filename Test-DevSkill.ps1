[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repositoryRoot = $PSScriptRoot
$null = & (Join-Path $repositoryRoot "Validate-DevSkill.ps1")
$testRoot = Join-Path $repositoryRoot ".dev-skill-test"
if (Test-Path -LiteralPath $testRoot) {
    $resolvedRepository = [IO.Path]::GetFullPath($repositoryRoot)
    $resolvedTest = [IO.Path]::GetFullPath($testRoot)
    if (-not $resolvedTest.StartsWith($resolvedRepository, [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe test directory: $resolvedTest" }
    Remove-Item -LiteralPath $resolvedTest -Recurse -Force
}

$agentsRoot = Join-Path $testRoot "agents"
$claudeRoot = Join-Path $testRoot "claude"
$codexRoot = Join-Path $testRoot "codex"
& (Join-Path $repositoryRoot "Install-DevSkill.ps1") -SourcePath $repositoryRoot -Scope Global -CanonicalRoot $agentsRoot -ClaudeRoot $claudeRoot -CodexRoot $codexRoot

foreach ($skillName in @("dev-skill-orchestrator", "dev-skill-developer", "dev-skill-tester", "dev-skill-reviewer")) {
    foreach ($root in @($agentsRoot, $claudeRoot, $codexRoot)) {
        $skillFile = Join-Path (Join-Path $root $skillName) "SKILL.md"
        if (-not (Test-Path -LiteralPath $skillFile)) { throw "Validation failed: $skillFile" }
    }
}

$projectRoot = Join-Path $testRoot "sample-project"
New-Item -ItemType Directory -Path $projectRoot | Out-Null
$originalProcessDirectory = [Environment]::CurrentDirectory
Push-Location $repositoryRoot
try {
    # Windows PowerShell can keep its process directory at System32 after Set-Location.
    # This verifies that a relative SourcePath follows the PowerShell location instead.
    [Environment]::CurrentDirectory = $env:SystemRoot
    & (Join-Path $repositoryRoot "Install-DevSkill.ps1") -SourcePath "." -Scope Project -ProjectPath $projectRoot
} finally {
    [Environment]::CurrentDirectory = $originalProcessDirectory
    Pop-Location
}
foreach ($skillName in @("dev-skill-orchestrator", "dev-skill-developer", "dev-skill-tester", "dev-skill-reviewer")) {
    foreach ($relativeRoot in @(".agents\skills", ".claude\skills", ".codex\skills")) {
        $skillFile = Join-Path (Join-Path (Join-Path $projectRoot $relativeRoot) $skillName) "SKILL.md"
        if (-not (Test-Path -LiteralPath $skillFile)) { throw "Project validation failed: $skillFile" }
    }
}

Write-Host "Global and project installer validation passed for all four skills." -ForegroundColor Green
