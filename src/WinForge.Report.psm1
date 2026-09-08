#Requires -Version 5.1
<#
    WinForge.Report — self-contained HTML report for one session:
    what was changed, previous → new value for every primitive, how to revert.
#>
Set-StrictMode -Version 2.0

function ConvertTo-HtmlSafe { param([AllowNull()]$Text) if ($null -eq $Text) { return '' }; return [System.Net.WebUtility]::HtmlEncode([string]$Text) }

function Format-EntryTarget {
    param($e)
    switch ($e.type) {
        'registry'        { "$($e.path)!$($e.name)" }
        'registryKey'     { "$($e.path) (key)" }
        'service'         { "service $($e.name)" }
        'task'            { "task $($e.path)$($e.name)" }
        'appx'            { "appx $($e.name)" }
        'appxProvisioned' { "provisioned $($e.name)" }
        'feature'         { "$($e.kind) $($e.name)" }
        'command'         { "$($e.shell): $($e.apply)" }
        default           { "$($e.type)" }
    }
}
function Format-EntryValue {
    param($v)
    if ($null -eq $v) { return '—' }
    if ($v -is [string] -or $v -is [int] -or $v -is [long] -or $v -is [bool]) { return "$v" }
    if ($v.PSObject.Properties['value']) { $k = if ($v.PSObject.Properties['kind']) { " ($($v.kind))" } else { '' }; return "$($v.value)$k" }
    if ($v.PSObject.Properties['start']) { $m = @{ 2 = 'Automatic'; 3 = 'Manual'; 4 = 'Disabled' }; $s = [int]$v.start; return "Start=$s $(if ($m.ContainsKey($s)) { $m[$s] })" }
    return (($v | ConvertTo-Json -Compress -Depth 3) -replace '[{}"]', '')
}

function Export-ForgeReport {
    <#
    .SYNOPSIS Write an HTML report for a session. Returns the file path.
    .PARAMETER Journal   In-memory journal object (from Get-ForgeJournal) — used even in dry-run.
    .PARAMETER Results   Result objects from Invoke-ForgeSession.
    .PARAMETER Tweaks    The tweak objects that were selected (for names / planned actions).
    #>
    [CmdletBinding()] param(
        [Parameter(Mandatory)]$Journal,
        [object[]]$Results = @(),
        [object[]]$Tweaks = @(),
        [hashtable]$StatesAfter = @{},
        $ScoreBefore = $null, $ScoreAfter = $null,
        [string]$Path = ''
    )
    $paths = Get-ForgePaths
    $dir = Join-Path $paths.Data 'reports'
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (-not $Path) { $Path = Join-Path $dir "$($Journal.id).html" }
    $os = Get-ForgeOsInfo
    $dry = [bool]$Journal.dryRun
    $byId = @{}; foreach ($t in $Tweaks) { $byId[$t.id] = $t }
    $resById = @{}; foreach ($r in $Results) { $resById[$r.Id] = $r }
    $jById = @{}; foreach ($jt in @($Journal.tweaks)) { $jById[$jt.id] = $jt }

    $applied = @($Results | Where-Object Status -eq 'Applied').Count
    $failed  = @($Results | Where-Object { $_.Status -in 'Failed', 'Partial' }).Count
    $skipped = @($Results | Where-Object Status -eq 'Skipped').Count
    $changes = 0; foreach ($jt in @($Journal.tweaks)) { $changes += @($jt.entries).Count }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<!doctype html><html lang="en"><head><meta charset="utf-8"><title>WinForge report ' + (ConvertTo-HtmlSafe $Journal.id) + '</title>')
    [void]$sb.AppendLine('<style>
:root{color-scheme:dark}body{margin:0;background:#0f1117;color:#e6e8ef;font:14px/1.5 "Segoe UI Variable","Segoe UI",system-ui,sans-serif}
.wrap{max-width:1100px;margin:0 auto;padding:28px 24px}h1{font-size:26px;margin:0 0 4px}h1 b{color:#4f8cff}.sub{color:#8b93a7;margin-bottom:22px}
.cards{display:flex;gap:12px;flex-wrap:wrap;margin-bottom:22px}.card{background:#1c2030;border:1px solid #2a2f45;border-radius:12px;padding:14px 18px;min-width:150px}
.card .v{font-size:28px;font-weight:700}.card .l{color:#8b93a7;font-size:12px}.ok{color:#34d399}.warn{color:#fbbf24}.bad{color:#f87171}.muted{color:#8b93a7}
.tweak{background:#171a23;border:1px solid #2a2f45;border-radius:12px;margin-bottom:12px;overflow:hidden}.tweak>summary{cursor:pointer;padding:12px 16px;font-weight:600;display:flex;gap:10px;align-items:center}
.pill{font-size:10px;font-weight:700;border-radius:10px;padding:2px 8px;color:#0f1117}.safe{background:#34d399}.moderate{background:#fbbf24}.advanced{background:#f87171}
table{width:100%;border-collapse:collapse;font-size:12px}th,td{text-align:left;padding:6px 10px;border-top:1px solid #2a2f45;vertical-align:top;font-family:Consolas,monospace;word-break:break-all}th{color:#8b93a7;font-family:inherit;font-weight:600}
code{background:#0b0d13;border:1px solid #2a2f45;border-radius:6px;padding:2px 6px}.revert{background:#1c2030;border:1px solid #2a2f45;border-radius:12px;padding:14px 18px;margin-top:22px}
.id{color:#4a5069;font-family:Consolas,monospace;font-size:11px;font-weight:400;margin-left:auto}.dry{background:#fbbf24;color:#0f1117;border-radius:8px;padding:6px 12px;display:inline-block;margin-bottom:16px;font-weight:600}
</style></head><body><div class="wrap">')
    [void]$sb.AppendLine("<h1>Win<b>Forge</b> session report</h1><div class='sub'>$(ConvertTo-HtmlSafe $Journal.created) · $(ConvertTo-HtmlSafe $Journal.label)$(if ($Journal.profile) { ' · profile ' + (ConvertTo-HtmlSafe $Journal.profile) }) · $(ConvertTo-HtmlSafe $os.ProductName) $(ConvertTo-HtmlSafe $os.DisplayVersion) build $(ConvertTo-HtmlSafe $os.FullBuild) · WinForge $($paths.Version)</div>")
    if ($dry) { [void]$sb.AppendLine('<div class="dry">DRY RUN — nothing was changed; this is what would happen</div>') }
    [void]$sb.AppendLine("<div class='cards'><div class='card'><div class='v ok'>$applied</div><div class='l'>applied</div></div><div class='card'><div class='v $(if ($failed) { 'bad' } else { 'muted' })'>$failed</div><div class='l'>failed / partial</div></div><div class='card'><div class='v muted'>$skipped</div><div class='l'>skipped (not applicable)</div></div><div class='card'><div class='v'>$changes</div><div class='l'>recorded changes</div></div>")
    if ($ScoreBefore -and $ScoreAfter) { [void]$sb.AppendLine("<div class='card'><div class='v'>$($ScoreBefore.Overall) → <span class='ok'>$($ScoreAfter.Overall)</span></div><div class='l'>WinForge score</div></div>") }
    [void]$sb.AppendLine('</div>')

    $order = if ($Tweaks.Count) { @($Tweaks.id) } else { @($Journal.tweaks | ForEach-Object id) }
    foreach ($id in $order) {
        $t = $byId[$id]; $r = $resById[$id]; $jt = $jById[$id]
        $name = if ($t) { Get-LocalizedText $t.name } else { $id }
        $risk = if ($t) { $t.risk } else { 'safe' }
        $status = if ($r) { $r.Status } else { 'Applied' }
        $cls = switch ($status) { 'Applied' { 'ok' } 'Skipped' { 'muted' } default { 'bad' } }
        $after = if ($StatesAfter.ContainsKey($id)) { " · now: $($StatesAfter[$id])" } else { '' }
        $reboot = if ($r -and $r.Reboot) { ' · ⟳ reboot' } else { '' }
        [void]$sb.AppendLine("<details class='tweak' open><summary><span class='pill $risk'>$($risk.ToUpper())</span>$(ConvertTo-HtmlSafe $name)<span class='$cls'>$status$after$reboot</span><span class='id'>$(ConvertTo-HtmlSafe $id)</span></summary>")
        if ($r -and $r.Message) { [void]$sb.AppendLine("<div style='padding:0 16px 10px' class='warn'>$(ConvertTo-HtmlSafe $r.Message)</div>") }
        $entries = @(if ($jt) { $jt.entries })
        if ($entries.Count) {
            [void]$sb.AppendLine('<table><tr><th>type</th><th>target</th><th>before</th><th>after</th></tr>')
            foreach ($e in $entries) {
                $before = if ($e.PSObject.Properties['before']) { Format-EntryValue $e.before } elseif ($e.type -in 'appx', 'appxProvisioned') { 'installed' } else { '—' }
                $afterV = if ($e.PSObject.Properties['after']) { Format-EntryValue $e.after } elseif ($e.type -in 'appx', 'appxProvisioned') { 'removed' } elseif ($e.type -eq 'command') { 'executed' } else { '—' }
                [void]$sb.AppendLine("<tr><td>$(ConvertTo-HtmlSafe $e.type)</td><td>$(ConvertTo-HtmlSafe (Format-EntryTarget $e))</td><td>$(ConvertTo-HtmlSafe $before)</td><td>$(ConvertTo-HtmlSafe $afterV)</td></tr>")
            }
            [void]$sb.AppendLine('</table>')
        } elseif ($t -and ($dry -or $status -eq 'Skipped')) {
            [void]$sb.AppendLine('<table><tr><th>planned action</th><th>target</th><th>value</th></tr>')
            foreach ($a in $t.actions) {
                $target = switch ($a.type) { 'registry' { "$($a.path)!$($a.name)" } 'registryDelete' { "$($a.path)!$($a.name)" } 'registryDeleteKey' { $a.path } 'service' { $a.name } 'task' { "$($a.path)$($a.name)" } 'appx' { $a.name } 'feature' { $a.name } 'capability' { $a.name } default { ($a.apply -replace '\s+', ' ') } }
                $val = switch ($a.type) { 'registry' { $a.value } 'service' { if ($a.PSObject.Properties['startup']) { $a.startup } else { 'Disabled' } } 'task' { 'Disabled' } 'appx' { 'remove' } 'feature' { $a.state } 'capability' { $a.state } default { '' } }
                [void]$sb.AppendLine("<tr><td>$(ConvertTo-HtmlSafe $a.type)</td><td>$(ConvertTo-HtmlSafe $target)</td><td>$(ConvertTo-HtmlSafe $val)</td></tr>")
            }
            [void]$sb.AppendLine('</table>')
        } else { [void]$sb.AppendLine("<div style='padding:0 16px 12px' class='muted'>nothing needed changing</div>") }
        [void]$sb.AppendLine('</details>')
    }
    $revertCmd = "powershell -ExecutionPolicy Bypass -File `"$(Join-Path $paths.Root 'WinForge.ps1')`" -RevertJournal $($Journal.id)"
    [void]$sb.AppendLine("<div class='revert'><b>Undo this whole session</b><br><span class='muted'>Run as administrator, or use Undo history in the GUI:</span><br><br><code>$(ConvertTo-HtmlSafe $revertCmd)</code><br><br><span class='muted'>Journal: $(ConvertTo-HtmlSafe (Join-Path $paths.Journal "$($Journal.id).json")) · Log: $(ConvertTo-HtmlSafe $paths.Log)</span></div>")
    [void]$sb.AppendLine('</div></body></html>')
    [IO.File]::WriteAllText($Path, $sb.ToString(), [Text.UTF8Encoding]::new($false))
    return $Path
}

function Open-ForgeReport {
    param([Parameter(Mandatory)][string]$Path)
    if ($env:OS -eq 'Windows_NT' -and (Test-Path -LiteralPath $Path)) { try { Start-Process $Path } catch { } }
}

Export-ModuleMember -Function Export-ForgeReport, Open-ForgeReport
