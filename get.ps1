<#
    WinForge bootstrapper — run from an elevated PowerShell:
        irm https://raw.githubusercontent.com/v1rus91/WinForge/main/get.ps1 | iex
    Downloads the latest release zip to %TEMP%\WinForge and starts the GUI.
    Pass arguments by wrapping:  & ([scriptblock]::Create((irm ...))) -Profile gaming -Silent
#>
param([Parameter(ValueFromRemainingArguments)][string[]]$ForgeArgs)
$ErrorActionPreference = 'Stop'
$repo = 'v1rus91/WinForge'
$dest = Join-Path $env:TEMP 'WinForge'
Write-Host '  Fetching latest WinForge release…' -ForegroundColor Cyan
$rel = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -Headers @{ 'User-Agent' = 'WinForge' }
$zipUrl = if ($rel.zipball_url) { $rel.zipball_url } else { "https://github.com/$repo/archive/refs/heads/main.zip" }
$zip = Join-Path $env:TEMP 'WinForge.zip'
Invoke-WebRequest $zipUrl -OutFile $zip -UseBasicParsing
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
Expand-Archive $zip $dest -Force
$inner = Get-ChildItem $dest -Directory | Select-Object -First 1
Get-ChildItem $inner.FullName -Recurse -Filter '*.ps*1' | Unblock-File
$args2 = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$($inner.FullName)\WinForge.ps1`"") + $ForgeArgs
Start-Process "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $args2 -Verb RunAs -Wait
