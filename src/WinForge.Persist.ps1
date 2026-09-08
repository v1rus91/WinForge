<#
    WinForge Persist — a logon-time watchdog that re-applies your chosen tweaks
    after Windows feature updates silently reset them.
    State lives in %ProgramData%\WinForge\persist.json  { ids: [...], profile: '', updated: '' }
#>

$script:PersistTaskName = 'WinForge Persist'
$script:PersistFile = Join-Path (Get-ForgePaths).Data 'persist.json'

function Get-ForgePersistState {
    if (-not (Test-Path -LiteralPath $script:PersistFile)) { return $null }
    try { Get-Content -LiteralPath $script:PersistFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $null }
}

function Set-ForgePersistState {
    param([string[]]$Ids, [string]$Profile = '', [bool]$Apps = $true)
    [PSCustomObject]@{ ids = $Ids; profile = $Profile; apps = $Apps; updated = (Get-Date -Format o) } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $script:PersistFile -Encoding UTF8
}

function Register-ForgePersist {
    <# Registers a scheduled task (current user, elevated) that runs `WinForge.ps1 -Reapply -Silent` 2 min after logon and daily. #>
    param([Parameter(Mandatory)][string[]]$Ids, [string]$Profile = '', [bool]$Apps = $true)
    if ($env:OS -ne 'Windows_NT') { return $false }
    Set-ForgePersistState -Ids $Ids -Profile $Profile -Apps $Apps
    $script = Join-Path (Get-ForgePaths).Root 'WinForge.ps1'
    $arg = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`" -Reapply -Silent"
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg
    $t1 = New-ScheduledTaskTrigger -AtLogOn; $t1.Delay = 'PT2M'
    $t2 = New-ScheduledTaskTrigger -Daily -At '12:00'
    # Run as the interactive user (not SYSTEM) so HKCU tweaks land in the right profile; elevated via RunLevel Highest.
    $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 20)
    Register-ScheduledTask -TaskName $script:PersistTaskName -Action $action -Trigger @($t1, $t2) -Principal $principal -Settings $settings -Force | Out-Null
    Write-ForgeLog "Persist watchdog registered for $($Ids.Count) tweak(s)" -Level Ok
    return $true
}

function Unregister-ForgePersist {
    if ($env:OS -eq 'Windows_NT') { Unregister-ScheduledTask -TaskName $script:PersistTaskName -Confirm:$false -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $script:PersistFile -Force -ErrorAction SilentlyContinue
    Write-ForgeLog 'Persist watchdog removed' -Level Ok
}

function Test-ForgePersistRegistered {
    if ($env:OS -ne 'Windows_NT') { return $false }
    return [bool](Get-ScheduledTask -TaskName $script:PersistTaskName -ErrorAction SilentlyContinue)
}

function Invoke-ForgeReapply {
    <# Called by the scheduled task: re-apply only tweaks whose live state is no longer 'Applied'.
       Bloatware sets are re-applied too (Windows re-installs Copilot/Outlook/Teams after feature updates) unless persist.json has apps=false.
       Advanced-risk tweaks are never touched unattended. #>
    $st = Get-ForgePersistState
    if (-not $st -or -not $st.ids) { Write-ForgeLog 'Persist: nothing configured' -Level Warn; return }
    $apps = -not ($st.PSObject.Properties['apps'] -and $st.apps -eq $false)
    $tweaks = Get-ForgeSelectionFromIds -Ids @($st.ids) | Where-Object { $_.risk -ne 'advanced' -and ($apps -or $_.category -ne 'bloatware') }
    $drifted = @()
    foreach ($t in $tweaks) {
        $s = Get-ForgeTweakState -Tweak $t
        if ($s -in 'NotApplied', 'Partial') { $drifted += $t }
    }
    if ($drifted.Count -eq 0) { Write-ForgeLog 'Persist: all tweaks still applied' -Level Ok; return }
    Write-ForgeLog "Persist: $($drifted.Count) tweak(s) drifted, re-applying" -Level Step
    Invoke-ForgeSession -Tweaks $drifted -Label 'persist' -Profile $st.profile -NoRestorePoint -NoReport | Out-Null
}
