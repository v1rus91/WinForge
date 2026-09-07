<#
    WinForge TUI — console menu. Dot-sourced by WinForge.ps1 (modules already loaded).
#>

function Write-TuiHeader { param([string]$Text) Write-Host ''; Write-Host "  ── $Text " -ForegroundColor Cyan -NoNewline; Write-Host ('─' * [math]::Max(4, 60 - $Text.Length)) -ForegroundColor DarkCyan }

function Read-TuiChoice { param([string]$Prompt = (Get-ForgeString 'prompt.choice')) Write-Host ''; return (Read-Host "  $Prompt").Trim() }

function Get-StateGlyph {
    param([string]$State)
    switch ($State) { 'Applied' { '●' } 'Partial' { '◐' } 'NotApplied' { '○' } default { '·' } }
}
function Get-StateColor { param([string]$State) switch ($State) { 'Applied' { 'Green' } 'Partial' { 'Yellow' } 'NotApplied' { 'DarkGray' } default { 'DarkGray' } } }
function Get-RiskColor  { param([string]$Risk)  switch ($Risk) { 'safe' { 'Green' } 'moderate' { 'Yellow' } default { 'Red' } } }

function Confirm-TuiApply {
    param([object[]]$Tweaks, [string]$Label)
    if (-not $Tweaks.Count) { Write-Host ('  ' + (Get-ForgeString 'msg.nothing')) -ForegroundColor Yellow; return }
    Write-TuiHeader $Label
    foreach ($t in $Tweaks) {
        Write-Host ("    [{0,-8}] " -f (Get-ForgeString "risk.$($t.risk)")) -ForegroundColor (Get-RiskColor $t.risk) -NoNewline
        Write-Host (Get-LocalizedText $t.name)
    }
    $a = Read-TuiChoice (Get-ForgeString 'prompt.confirm' @($Tweaks.Count))
    if ($a -notmatch '^[yYтТ]') { return }
    $rp = -not (Get-ForgeDryRun)
    if ($rp) { $b = Read-TuiChoice (Get-ForgeString 'prompt.restorepoint'); $rp = ($b -notmatch '^[nNнН]') }
    Invoke-ForgeSession -Tweaks $Tweaks -Label $Label -NoRestorePoint:(-not $rp) | Out-Null
    Read-Host '  Enter ↵' | Out-Null
}

function Show-TuiProfiles {
    while ($true) {
        Write-TuiHeader (Get-ForgeString 'menu.profile')
        $profiles = @(Import-ForgeProfiles)
        $i = 0
        foreach ($p in $profiles) {
            $i++
            $n = (Resolve-ForgeProfile $p).Count
            Write-Host ("   {0}) {1} {2,-28} {3,3} tweaks" -f $i, $p.icon, (Get-LocalizedText $p.name), $n) -ForegroundColor White
            Write-Host ("        " + (Get-LocalizedText $p.description)) -ForegroundColor DarkGray
        }
        Write-Host '   b) ← back' -ForegroundColor DarkGray
        $c = Read-TuiChoice
        if ($c -eq 'b' -or $c -eq '') { return }
        if ($c -match '^\d+$' -and [int]$c -ge 1 -and [int]$c -le $profiles.Count) {
            $p = $profiles[[int]$c - 1]
            Confirm-TuiApply -Tweaks (Resolve-ForgeProfile $p) -Label "profile:$($p.id)"
        }
    }
}

function Show-TuiTweakList {
    param([object[]]$Tweaks, [string]$Title)
    $selected = @{}
    $states = @{}
    Write-Host '  scanning state…' -ForegroundColor DarkGray
    foreach ($t in $Tweaks) { $states[$t.id] = Get-ForgeTweakState -Tweak $t }
    while ($true) {
        Write-TuiHeader $Title
        $i = 0
        foreach ($t in $Tweaks) {
            $i++
            $mark = if ($selected[$t.id]) { '[x]' } else { '[ ]' }
            $st = $states[$t.id]
            Write-Host ("   {0,2} {1} " -f $i, $mark) -NoNewline -ForegroundColor White
            Write-Host (Get-StateGlyph $st) -NoNewline -ForegroundColor (Get-StateColor $st)
            Write-Host (" {0,-8} " -f $t.risk) -NoNewline -ForegroundColor (Get-RiskColor $t.risk)
            $reason = ''
            $ok = Test-ForgeTweakApplicable -Tweak $t -Reason ([ref]$reason)
            Write-Host (Get-LocalizedText $t.name) -NoNewline -ForegroundColor $(if ($ok) { 'Gray' } else { 'DarkGray' })
            if (-not $ok) { Write-Host "  ($reason)" -ForegroundColor DarkYellow } else { Write-Host '' }
        }
        Write-Host ''
        Write-Host '   #   toggle    a) select all safe   n) none   i #) info   A) apply selected   R) revert selected   b) back' -ForegroundColor DarkGray
        $c = Read-TuiChoice
        switch -Regex ($c) {
            '^b$|^$' { return }
            '^a$'    { foreach ($t in $Tweaks) { if ($t.risk -eq 'safe') { $selected[$t.id] = $true } } }
            '^n$'    { $selected = @{} }
            '^i\s*(\d+)$' {
                $t = $Tweaks[[int]$Matches[1] - 1]
                Write-Host ''
                Write-Host ("  " + (Get-LocalizedText $t.name)) -ForegroundColor Cyan
                Write-Host ("  " + (Get-LocalizedText $t.description)) -ForegroundColor Gray
                Write-Host ("  id: {0}   risk: {1}   reboot: {2}   reversible: {3}" -f $t.id, $t.risk, [bool]($t.PSObject.Properties['reboot'] -and $t.reboot), (-not ($t.PSObject.Properties['reversible'] -and $t.reversible -eq $false)))
                foreach ($a in $t.actions) {
                    $desc = switch ($a.type) {
                        'registry' { "$($a.path)!$($a.name) = $($a.value)" }
                        'registryDelete' { "delete $($a.path)!$($a.name)" }
                        'registryDeleteKey' { "delete key $($a.path)" }
                        'service' { "service $($a.name) → $(if ($a.PSObject.Properties['startup']) { $a.startup } else { 'Disabled' })" }
                        'task' { "task $($a.path)$($a.name) → disabled" }
                        'appx' { "remove appx $($a.name)" }
                        'feature' { "feature $($a.name) → $($a.state)" }
                        'capability' { "capability $($a.name) → $($a.state)" }
                        default { "$($a.type): $(($a.apply -split "`n")[0].Substring(0, [math]::Min(90, $a.apply.Length)))…" }
                    }
                    Write-Host "    · $desc" -ForegroundColor DarkGray
                }
                Read-Host '  Enter ↵' | Out-Null
            }
            '^A$' {
                $sel = @($Tweaks | Where-Object { $selected[$_.id] })
                Confirm-TuiApply -Tweaks $sel -Label $Title
                foreach ($t in $sel) { $states[$t.id] = Get-ForgeTweakState -Tweak $t }
            }
            '^R$' {
                $sel = @($Tweaks | Where-Object { $selected[$_.id] })
                if ($sel.Count) { Invoke-ForgeRevertSession -Tweaks $sel | Out-Null; foreach ($t in $sel) { $states[$t.id] = Get-ForgeTweakState -Tweak $t }; Read-Host '  Enter ↵' | Out-Null }
            }
            '^\d+$' {
                $n = [int]$c
                if ($n -ge 1 -and $n -le $Tweaks.Count) { $id = $Tweaks[$n - 1].id; $selected[$id] = -not $selected[$id] }
            }
        }
    }
}

function Show-TuiCategories {
    $cats = Get-ForgeCategories
    while ($true) {
        Write-TuiHeader (Get-ForgeString 'menu.browse')
        $keys = @($cats.Keys)
        $i = 0
        foreach ($k in $keys) { $i++; $n = (Get-ForgeTweak -Category $k).Count; Write-Host ("   {0,2}) {1} {2,-14} {3,3}" -f $i, $cats[$k].icon, $k, $n) -ForegroundColor White }
        Write-Host '    b) ← back' -ForegroundColor DarkGray
        $c = Read-TuiChoice
        if ($c -eq 'b' -or $c -eq '') { return }
        if ($c -match '^\d+$' -and [int]$c -ge 1 -and [int]$c -le $keys.Count) {
            $k = $keys[[int]$c - 1]
            Show-TuiTweakList -Tweaks (Get-ForgeTweak -Category $k) -Title $k
        }
    }
}

function Show-TuiJournals {
    while ($true) {
        Write-TuiHeader (Get-ForgeString 'menu.revert')
        $js = @(Get-ForgeJournalList | Where-Object Label -ne 'revert')
        if (-not $js.Count) { Write-Host '   (no journals yet)' -ForegroundColor DarkGray; Read-Host '  Enter ↵' | Out-Null; return }
        $i = 0
        foreach ($j in $js) { $i++; Write-Host ("   {0,2}) {1}  {2,-18} {3,3} tweaks" -f $i, $j.Created.Substring(0, 19).Replace('T', ' '), $j.Label, $j.Tweaks) -ForegroundColor White }
        Write-Host '    b) ← back' -ForegroundColor DarkGray
        $c = Read-TuiChoice
        if ($c -eq 'b' -or $c -eq '') { return }
        if ($c -match '^\d+$' -and [int]$c -ge 1 -and [int]$c -le $js.Count) {
            $j = $js[[int]$c - 1]
            $a = Read-TuiChoice "Revert ALL $($j.Tweaks) tweak(s) from $($j.Id)? [y/N]"
            if ($a -match '^[yY]') { New-ForgeJournal -Label 'revert' | Out-Null; Restore-ForgeJournal -File $j.File | Out-Null; Save-ForgeJournal | Out-Null; Read-Host '  Enter ↵' | Out-Null }
        }
    }
}

function Show-TuiStatus {
    Write-TuiHeader (Get-ForgeString 'menu.status')
    $r = Get-ForgeHealthReport
    Write-Host "  $($r.Os.ProductName) $($r.Os.DisplayVersion)  build $($r.Os.FullBuild)  $($r.Os.Edition)"
    Write-Host "  $($r.Hardware.Cpu) · $($r.Hardware.RamGB) GB RAM · $(($r.Hardware.Gpu | ForEach-Object Name) -join ', ')"
    Write-Host "  processes $($r.Runtime.Processes) · services $($r.Runtime.RunningServices) · startup $($r.Runtime.StartupEntries) · appx $($r.Runtime.AppxCount) · RAM $($r.Runtime.RamUsedPct)%"
    if ($r.Score) {
        Write-Host ''
        foreach ($k in 'Privacy', 'Performance', 'Bloat', 'Overall') {
            $v = $r.Score.$k; $bar = ('█' * [int]($v / 5)).PadRight(20, '░')
            Write-Host ("  {0,-12} {1} {2,3}%" -f $k, $bar, $v) -ForegroundColor $(if ($v -ge 70) { 'Green' } elseif ($v -ge 40) { 'Yellow' } else { 'Red' })
        }
    }
    Read-Host '  Enter ↵' | Out-Null
}

function Show-TuiSettings {
    $cfg = Get-ForgeConfig
    while ($true) {
        Write-TuiHeader (Get-ForgeString 'menu.settings')
        Write-Host ("   1) Language            : {0}" -f $cfg.language)
        Write-Host ("   2) Restore point by default : {0}" -f $cfg.createRestorePoint)
        Write-Host ("   3) Dry run (this session)   : {0}" -f (Get-ForgeDryRun))
        Write-Host ("   4) Persist watchdog     : {0}" -f (Test-ForgePersistRegistered))
        Write-Host ("   5) Open logs folder")
        Write-Host '    b) ← back' -ForegroundColor DarkGray
        $c = Read-TuiChoice
        switch ($c) {
            '1' { $cfg.language = if ($cfg.language -eq 'uk') { 'en' } else { 'uk' }; Save-ForgeConfig $cfg; Set-ForgeLanguage $cfg.language }
            '2' { $cfg.createRestorePoint = -not $cfg.createRestorePoint; Save-ForgeConfig $cfg }
            '3' { Set-ForgeDryRun (-not (Get-ForgeDryRun)) }
            '4' { if (Test-ForgePersistRegistered) { Unregister-ForgePersist } else { $st = Get-ForgePersistState; if ($st -and $st.ids) { Register-ForgePersist -Ids @($st.ids) -Profile $st.profile | Out-Null } else { Write-Host '   Apply a profile with -Persist on first.' -ForegroundColor Yellow } } }
            '5' { if ($env:OS -eq 'Windows_NT') { Start-Process explorer.exe (Get-ForgePaths).Logs } else { Write-Host (Get-ForgePaths).Logs } }
            default { return }
        }
    }
}

function Start-ForgeTui {
    while ($true) {
        Write-TuiHeader (Get-ForgeString 'menu.title')
        $items = @(
            @{ k = '1'; s = 'menu.profile' }, @{ k = '2'; s = 'menu.browse' }, @{ k = '3'; s = 'menu.search' },
            @{ k = '4'; s = 'menu.status' }, @{ k = '5'; s = 'menu.revert' }, @{ k = '6'; s = 'menu.cleanup' },
            @{ k = '7'; s = 'menu.gui' }, @{ k = '8'; s = 'menu.settings' }, @{ k = 'q'; s = 'menu.exit' }
        )
        foreach ($it in $items) { Write-Host ("   {0}) {1}" -f $it.k, (Get-ForgeString $it.s)) -ForegroundColor White }
        if (Get-ForgeDryRun) { Write-Host ('   ' + (Get-ForgeString 'msg.dryrun')) -ForegroundColor Yellow }
        $c = Read-TuiChoice
        switch ($c) {
            '1' { Show-TuiProfiles }
            '2' { Show-TuiCategories }
            '3' { $q = Read-TuiChoice 'search'; if ($q) { Show-TuiTweakList -Tweaks (Get-ForgeTweak -Search $q) -Title "search: $q" } }
            '4' { Show-TuiStatus }
            '5' { Show-TuiJournals }
            '6' { Get-ForgeCleanupTargets | Format-Table Name, MB -AutoSize | Out-Host; $a = Read-TuiChoice 'Clean all? [y/N]'; if ($a -match '^[yY]') { $mb = Invoke-ForgeCleanup; Write-Host "  Freed ~$mb MB" -ForegroundColor Green; Read-Host '  Enter ↵' | Out-Null } }
            '7' { if ($env:OS -eq 'Windows_NT') { . (Join-Path (Get-ForgePaths).Root 'src\WinForge.Gui.ps1'); Start-ForgeGui } else { Write-Host '  GUI requires Windows.' -ForegroundColor Yellow } }
            '8' { Show-TuiSettings }
            'q' { return }
            default { }
        }
    }
}
