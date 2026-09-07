<# Runs PSScriptAnalyzer over the code base. Exit 1 on errors. #>
param([switch]$Fix)
$root = Split-Path -Parent $PSScriptRoot
Import-Module PSScriptAnalyzer -ErrorAction Stop
$settings = @{
    ExcludeRules = @('PSAvoidUsingWriteHost', 'PSUseShouldProcessForStateChangingFunctions', 'PSAvoidUsingInvokeExpression', 'PSAvoidGlobalVars', 'PSUseSingularNouns', 'PSAvoidUsingPositionalParameters', 'PSReviewUnusedParameter', 'PSAvoidUsingEmptyCatchBlock', 'PSUseDeclaredVarsMoreThanAssignments')
    Severity = @('Error', 'Warning')
}
$files = Get-ChildItem $root -Recurse -Include *.ps1, *.psm1 | Where-Object { $_.FullName -notmatch '[\\/]tests[\\/]' }
$results = foreach ($f in $files) { Invoke-ScriptAnalyzer -Path $f.FullName -Settings $settings -Fix:$Fix }
$results | Format-Table RuleName, Severity, ScriptName, Line, Message -AutoSize -Wrap | Out-String -Width 220 | Write-Host
$errs = @($results | Where-Object Severity -eq 'Error').Count
Write-Host "$($files.Count) files, $(@($results).Count) findings, $errs errors"
if ($errs) { exit 1 }
