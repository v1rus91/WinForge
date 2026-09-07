@echo off
:: WinForge launcher — elevates and runs the GUI in Windows PowerShell 5.1
set "SCRIPT=%~dp0WinForge.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%SCRIPT%\" %*' -Verb RunAs"
