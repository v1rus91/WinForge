<# Runs Pester tests. #>
param([switch]$CI)
$root = Split-Path -Parent $PSScriptRoot
Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop
$cfg = New-PesterConfiguration
$cfg.Run.Path = Join-Path $root 'tests'
$cfg.Output.Verbosity = 'Detailed'
if ($CI) { $cfg.TestResult.Enabled = $true; $cfg.TestResult.OutputPath = Join-Path $root 'testResults.xml'; $cfg.Run.Exit = $true }
Invoke-Pester -Configuration $cfg
