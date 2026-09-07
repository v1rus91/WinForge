#Requires -Version 5.1
<#
    WinForge.Session — orchestration of one "apply" or "revert" run:
    restore point → journal → tweaks → explorer restart → summary.
    Shared by the CLI, TUI, GUI and the Persist watchdog.
#>
Set-StrictMode -Version 2.0

function Invoke-ForgeSession {
    <#
    .SYNOPSIS Apply a list of tweaks as one journaled session.
    .OUTPUTS PSCustomObject { Applied, Skipped, Failed, Reboot, JournalFile, Results }
    #>
    [CmdletBinding()] param(
        [Parameter(Mandatory)][object[]]$Tweaks,
        [string]$Label = 'session',
        [string]$Profile = '',
        [switch]$NoRestorePoint,
        [switch]$DefaultUser,
        [scriptblock]$Progress = $null
    )
    if ($Tweaks.Count -eq 0) { Write-ForgeLog 'Nothing to apply' -Level Warn; return $null }
    $os = Get-ForgeOsInfo
    Write-ForgeLog "WinForge $((Get-ForgePaths).Version) on $($os.ProductName) $($os.DisplayVersion) build $($os.FullBuild)" -Level Info
    if (Get-ForgeDryRun) { Write-ForgeLog (Get-ForgeString 'msg.dryrun') -Level Warn }
    if (-not $NoRestorePoint -and -not (Get-ForgeDryRun)) { New-ForgeRestorePoint -Description "WinForge: $Label" | Out-Null }

    New-ForgeJournal -Label $Label -Profile $Profile | Out-Null
    $results = New-Object System.Collections.ArrayList
    $i = 0
    foreach ($t in $Tweaks) {
        $i++
        if ($Progress) { try { & $Progress $i $Tweaks.Count $t } catch { } }
        $r = Invoke-ForgeTweak -Tweak $t -DefaultUser:$DefaultUser
        [void]$results.Add($r)
    }
    Dismount-DefaultUserHive
    $file = Save-ForgeJournal
    if (Test-ForgeExplorerRestartNeeded) { Restart-ForgeExplorer }

    $applied = @($results | Where-Object Status -eq 'Applied').Count
    $skipped = @($results | Where-Object Status -eq 'Skipped').Count
    $failed  = @($results | Where-Object { $_.Status -in 'Failed', 'Partial' }).Count
    $reboot  = @($results | Where-Object { $_.Reboot -and $_.Status -ne 'Skipped' }).Count -gt 0
    Write-ForgeLog (Get-ForgeString 'msg.done' @($applied, $skipped, $failed)) -Level Ok
    if ($reboot) { Write-ForgeLog (Get-ForgeString 'msg.reboot') -Level Warn }
    if ($file) { Write-ForgeLog "Journal: $file" -Level Info }
    [PSCustomObject]@{ Applied = $applied; Skipped = $skipped; Failed = $failed; Reboot = $reboot; JournalFile = $file; Results = $results.ToArray() }
}

function Invoke-ForgeRevertSession {
    <# Revert a set of tweak objects (explicit revert or journal lookup each). #>
    [CmdletBinding()] param([Parameter(Mandatory)][object[]]$Tweaks, [scriptblock]$Progress = $null)
    New-ForgeJournal -Label 'revert' | Out-Null
    $n = 0; $i = 0
    foreach ($t in $Tweaks) {
        $i++
        if ($Progress) { try { & $Progress $i $Tweaks.Count $t } catch { } }
        $r = Undo-ForgeTweak -Tweak $t
        if ($r.Status -eq 'Reverted') { $n++ }
    }
    Dismount-DefaultUserHive
    Save-ForgeJournal | Out-Null
    if (Test-ForgeExplorerRestartNeeded) { Restart-ForgeExplorer }
    Write-ForgeLog (Get-ForgeString 'msg.reverted' @($n)) -Level Ok
    return $n
}

function Get-ForgeSelectionFromIds {
    <# Resolve a list of ids / wildcards / category: patterns to tweak objects, preserving catalog order. #>
    param([Parameter(Mandatory)][string[]]$Ids)
    $all = Import-ForgeCatalog
    $hit = @{}
    foreach ($pat in $Ids) {
        $p = $pat.Trim(); if (-not $p) { continue }
        foreach ($t in $all) { if (Test-ForgePattern -Pattern $p -Tweak $t) { $hit[$t.id] = $true } }
    }
    return @($all | Where-Object { $hit.ContainsKey($_.id) })
}

Export-ModuleMember -Function *-Forge*
