[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repositoryRoot = $PSScriptRoot
$skillNames = @("dev-skill-orchestrator", "dev-skill-developer", "dev-skill-tester", "dev-skill-reviewer")

foreach ($skillName in $skillNames) {
    $skillRoot = Join-Path (Join-Path $repositoryRoot "skills") $skillName
    $skillFile = Join-Path $skillRoot "SKILL.md"
    $agentFile = Join-Path $skillRoot "agents\openai.yaml"
    if (-not (Test-Path -LiteralPath $skillFile)) { throw "Missing $skillFile" }
    if (-not (Test-Path -LiteralPath $agentFile)) { throw "Missing $agentFile" }

    $content = Get-Content -LiteralPath $skillFile -Raw
    if ($content -notmatch "(?s)^---\r?\nname: $([regex]::Escape($skillName))\r?\ndescription: .+?\r?\n---") {
        throw "Invalid frontmatter: $skillFile"
    }
    if ($content -match "TODO") { throw "Unresolved TODO: $skillFile" }

    foreach ($match in [regex]::Matches($content, "\]\((?<path>[^)#]+\.md)\)")) {
        $linkedFile = Join-Path $skillRoot $match.Groups["path"].Value
        if (-not (Test-Path -LiteralPath $linkedFile)) { throw "Broken reference in $skillFile`: $linkedFile" }
    }
}

$parseErrors = @()
Get-ChildItem -LiteralPath $repositoryRoot -Filter "*.ps1" -Recurse | ForEach-Object {
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors)
    $parseErrors += $errors
}
if ($parseErrors.Count -gt 0) { throw ($parseErrors | Out-String) }

Write-Host "Structure, references and PowerShell syntax are valid." -ForegroundColor Green

