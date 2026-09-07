<#
.SYNOPSIS
    WinForge — a Windows 11 optimizer that knows exactly what it changed and can undo it.

.DESCRIPTION
    145+ declarative tweaks (privacy, AI/Copilot/Recall, bloatware, performance, gaming, services,
    UI, Explorer, Edge, updates, network, security, power) with live state detection, journaled undo,
    build-gated compatibility (22H2 → 25H2), profiles, a WPF GUI, a console TUI, a silent CLI and a
    "Persist" watchdog that re-applies your settings after feature updates.

.PARAMETER Gui           Launch the WPF interface (default when double-clicked with no arguments).
.PARAMETER Cli           Force the console menu.
.PARAMETER Profile       Apply a profile by id: balanced | privacy | gaming | minimal | developer | laptop
.PARAMETER Apply         Apply tweaks by id / wildcard / category:x / tag:x / risk:x (comma separated).
.PARAMETER Revert        Revert tweaks by id (uses explicit revert actions or the newest journal).
.PARAMETER RevertJournal Revert an entire journal: its id, or "last".
.PARAMETER List          Print the catalog (optionally filtered with -Category / -Search).
.PARAMETER Status        Show OS/hardware info, live tweak states and the WinForge Score.
.PARAMETER DryRun        Log what would change without touching the system.
.PARAMETER Silent        No prompts, no restore-point question (for scripts / deployment).
.PARAMETER NoRestorePoint Skip the automatic restore point.
.PARAMETER DefaultUser   Also write HKCU tweaks into the Default user hive (new accounts / sysprep).
.PARAMETER Persist       on | off — register/unregister the logon watchdog for the tweaks you apply in this run.
.PARAMETER Reapply       Used by the watchdog: re-apply drifted tweaks from persist.json.
.PARAMETER Export        Save the ids selected via -Apply/-Profile to a JSON profile file.
.PARAMETER Import        Apply a JSON profile file previously exported (or hand-written).
.PARAMETER Cleanup       Delete temp/caches/update leftovers and report MB freed.
.PARAMETER Validate      Validate catalog + profiles and exit (CI).
.PARAMETER Language      en | uk (defaults to config / system UI culture).

.EXAMPLE
    .\WinForge.ps1                                   # GUI
    .\WinForge.ps1 -Profile gaming -DryRun           # preview
    .\WinForge.ps1 -Profile balanced -Silent -Persist on
    .\WinForge.ps1 -Apply privacy.telemetry,ai.*,category:edge
    .\WinForge.ps1 -Revert ai.copilot
    .\WinForge.ps1 -RevertJournal last
    .\WinForge.ps1 -Status
#>
[CmdletBinding()]
param(
    [switch]$Gui,
    [switch]$Cli,
    [string]$Profile,
    [string[]]$Apply,
    [string[]]$Revert,
    [string]$RevertJournal,
    [switch]$List,
    [string]$Category,
    [string]$Search,
    [switch]$Status,
    [switch]$DryRun,
    [switch]$Silent,
    [switch]$NoRestorePoint,
    [switch]$DefaultUser,
    [ValidateSet('on', 'off', '')][string]$Persist = '',
    [switch]$Reapply,
    [string]$Export,
    [string]$Import,
    [switch]$Cleanup,
    [switch]$Validate,
    [ValidateSet('en', 'uk', '')][string]$Language = ''
)

$ErrorActionPreference = 'Stop'
$script:Root = $PSScriptRoot
if (-not $script:Root) { $script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path }
$IsWinHost = ($env:OS -eq 'Windows_NT')

# ---------------------------------------------------------------- elevation
function Test-IsAdmin {
    if (-not $IsWinHost) { return $true }
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
$needsAdmin = -not ($List -or $Validate -or $Status -or $DryRun)
if ($IsWinHost -and -not (Test-IsAdmin) -and $needsAdmin) {
    Write-Host 'WinForge needs administrator rights - relaunching elevated...' -ForegroundColor Yellow
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$($MyInvocation.MyCommand.Path)`"")
    foreach ($kv in $PSBoundParameters.GetEnumerator()) {
        if ($kv.Value -is [switch]) { if ($kv.Value.IsPresent) { $argList += "-$($kv.Key)" } }
        elseif ($kv.Value -is [array]) { $argList += "-$($kv.Key)"; $argList += ('"' + ($kv.Value -join ',') + '"') }
        else { $argList += "-$($kv.Key)"; $argList += "`"$($kv.Value)`"" }
    }
    $host5 = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    Start-Process -FilePath $host5 -ArgumentList $argList -Verb RunAs
    exit
}

# ---------------------------------------------------------------- modules
if ($IsWinHost -and $PSVersionTable.PSEdition -eq 'Core') {
    # Appx / DISM cmdlets are unreliable in pwsh 7 — bridge them through Windows PowerShell.
    foreach ($m in 'Appx', 'Dism', 'ScheduledTasks') { try { Import-Module $m -UseWindowsPowerShell -WarningAction SilentlyContinue -ErrorAction Stop } catch { } }
}
Import-Module (Join-Path $script:Root 'src\WinForge.Core.psm1')        -Force -DisableNameChecking
Import-Module (Join-Path $script:Root 'src\WinForge.Catalog.psm1')     -Force -DisableNameChecking
Import-Module (Join-Path $script:Root 'src\WinForge.Diagnostics.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $script:Root 'src\WinForge.Session.psm1')     -Force -DisableNameChecking
. (Join-Path $script:Root 'src\WinForge.Persist.ps1')

$config = Get-ForgeConfig
$lang = if ($Language) { $Language } elseif ($config.language) { $config.language } else { 'en' }
if (-not $Language -and -not $config.language -and (Get-Culture).TwoLetterISOLanguageName -eq 'uk') { $lang = 'uk' }
Set-ForgeLanguage $lang
Set-ForgeDryRun ([bool]$DryRun)
Set-ForgeQuiet ([bool]($Silent -and -not $VerbosePreference))
Initialize-ForgeLog -Name $(if ($Reapply) { 'persist' } elseif ($Gui) { 'gui' } else { 'run' }) | Out-Null

function Show-Banner {
    $v = (Get-ForgePaths).Version
    Write-Host ''
    Write-Host '  ██╗    ██╗██╗███╗   ██╗███████╗ ██████╗ ██████╗  ██████╗ ███████╗' -ForegroundColor Cyan
    Write-Host '  ██║    ██║██║████╗  ██║██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝' -ForegroundColor Cyan
    Write-Host '  ██║ █╗ ██║██║██╔██╗ ██║█████╗  ██║   ██║██████╔╝██║  ███╗█████╗  ' -ForegroundColor Cyan
    Write-Host '  ██║███╗██║██║██║╚██╗██║██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝  ' -ForegroundColor DarkCyan
    Write-Host '  ╚███╔███╔╝██║██║ ╚████║██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗' -ForegroundColor DarkCyan
    Write-Host '   ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝' -ForegroundColor DarkCyan
    Write-Host ("   v$v  ·  " + (Get-ForgeString 'app.tagline')) -ForegroundColor Gray
    Write-Host ''
}

# ---------------------------------------------------------------- non-interactive commands
if ($Validate) {
    $e = @(Test-ForgeCatalog) + @(Test-ForgeDetectBlocks) + @(Test-ForgeProfiles)
    if ($e.Count) { $e | ForEach-Object { Write-Host "  ✗ $_" -ForegroundColor Red }; exit 1 }
    Write-Host "  ✓ catalog OK: $((Import-ForgeCatalog).Count) tweaks, $((Import-ForgeProfiles).Count) profiles" -ForegroundColor Green
    exit 0
}

if ($List) {
    Show-Banner
    $tw = Get-ForgeTweak -Category $Category -Search $Search
    $cats = Get-ForgeCategories
    foreach ($g in ($tw | Group-Object category | Sort-Object { $cats[$_.Name].order })) {
        Write-Host ("  {0} {1}" -f $cats[$g.Name].icon, $g.Name.ToUpper()) -ForegroundColor Cyan
        foreach ($t in $g.Group) {
            $rc = switch ($t.risk) { 'safe' { 'Green' } 'moderate' { 'Yellow' } default { 'Red' } }
            $gate = if ($t.PSObject.Properties['minBuild'] -and $t.minBuild) { " (build $($t.minBuild)+)" } else { '' }
            Write-Host ("    {0,-38} " -f $t.id) -NoNewline
            Write-Host ("{0,-8} " -f $t.risk) -ForegroundColor $rc -NoNewline
            Write-Host ((Get-LocalizedText $t.name) + $gate)
        }
    }
    Write-Host "`n  $($tw.Count) tweak(s)" -ForegroundColor Gray
    exit 0
}

if ($Status) {
    Show-Banner
    $r = Get-ForgeHealthReport -SkipScore:(-not $IsWinHost)
    Write-Host "  OS        : $($r.Os.ProductName) $($r.Os.DisplayVersion) (build $($r.Os.FullBuild), $($r.Os.Edition))"
    Write-Host "  CPU       : $($r.Hardware.Cpu)  [$($r.Hardware.Cores)C/$($r.Hardware.Threads)T]"
    Write-Host "  RAM       : $($r.Hardware.RamGB) GB  ($($r.Runtime.RamUsedPct)% used)"
    foreach ($g in $r.Hardware.Gpu) { Write-Host "  GPU       : $($g.Name)  $($g.VramGB) GB  drv $($g.Driver)" }
    foreach ($d in $r.Hardware.Disks) { Write-Host "  Disk      : $($d.Name)  $($d.Type)/$($d.Bus)  $($d.SizeGB) GB  $($d.Health)" }
    Write-Host "  SecureBoot: $($r.Hardware.SecureBoot)   VBS: $($r.Hardware.Vbs)   Laptop: $($r.Hardware.Laptop)"
    Write-Host "  Processes : $($r.Runtime.Processes)   Services running: $($r.Runtime.RunningServices)   Startup entries: $($r.Runtime.StartupEntries)   Appx: $($r.Runtime.AppxCount)"
    if ($r.Score) {
        Write-Host ''
        Write-Host ('  ' + (Get-ForgeString 'msg.score' @($r.Score.Privacy, $r.Score.Performance, $r.Score.Bloat, $r.Score.Overall))) -ForegroundColor Cyan
        foreach ($k in 'Privacy', 'Performance', 'Bloat') {
            $v = $r.Score.$k; $bar = ('█' * [int]($v / 5)).PadRight(20, '░')
            Write-Host ("  {0,-12} {1} {2,3}%" -f $k, $bar, $v) -ForegroundColor $(if ($v -ge 70) { 'Green' } elseif ($v -ge 40) { 'Yellow' } else { 'Red' })
        }
    }
    exit 0
}

if ($Cleanup) {
    Show-Banner
    Get-ForgeCleanupTargets | Format-Table Name, MB -AutoSize | Out-Host
    if (-not $Silent) { $a = Read-Host 'Clean all of the above? [y/N]'; if ($a -notmatch '^y') { exit 0 } }
    $mb = Invoke-ForgeCleanup
    Write-Host "  Freed ~$mb MB" -ForegroundColor Green
    exit 0
}

if ($Reapply) { Invoke-ForgeReapply; exit 0 }

if ($RevertJournal) {
    $journals = @(Get-ForgeJournalList | Where-Object Label -ne 'revert')
    $j = if ($RevertJournal -eq 'last') { $journals | Select-Object -First 1 } else { $journals | Where-Object Id -like "*$RevertJournal*" | Select-Object -First 1 }
    if (-not $j) { Write-Host 'Journal not found. Available:' -ForegroundColor Red; $journals | Format-Table Id, Created, Profile, Tweaks | Out-Host; exit 1 }
    New-ForgeJournal -Label 'revert' | Out-Null
    $n = Restore-ForgeJournal -File $j.File
    Save-ForgeJournal | Out-Null
    exit 0
}

if ($Revert) {
    $sel = Get-ForgeSelectionFromIds -Ids $Revert
    if (-not $sel.Count) { Write-Host (Get-ForgeString 'msg.nothing') -ForegroundColor Yellow; exit 1 }
    Invoke-ForgeRevertSession -Tweaks $sel | Out-Null
    exit 0
}

$selection = @()
$label = 'custom'
if ($Import) {
    $p = Get-Content -LiteralPath $Import -Raw -Encoding UTF8 | ConvertFrom-Json
    $selection = Resolve-ForgeProfile -Profile $p; $label = "import:$($p.id)"
} elseif ($Profile) {
    $p = Import-ForgeProfiles | Where-Object id -eq $Profile.ToLower() | Select-Object -First 1
    if (-not $p) { Write-Host "Unknown profile '$Profile'. Available: $((Import-ForgeProfiles).id -join ', ')" -ForegroundColor Red; exit 1 }
    $selection = Resolve-ForgeProfile -Profile $p; $label = "profile:$($p.id)"
} elseif ($Apply) {
    $selection = Get-ForgeSelectionFromIds -Ids $Apply
}

if ($Export -and $selection.Count) {
    Export-ForgeSelection -Ids @($selection.id) -Path $Export -Name ([IO.Path]::GetFileNameWithoutExtension($Export))
    Write-Host "  Exported $($selection.Count) tweak id(s) to $Export" -ForegroundColor Green
    if (-not ($Profile -or $Apply -or $Import)) { exit 0 }
}

if ($selection.Count) {
    Show-Banner
    Write-Host "  $label → $($selection.Count) tweak(s):" -ForegroundColor Cyan
    foreach ($t in $selection) {
        $rc = switch ($t.risk) { 'safe' { 'Green' } 'moderate' { 'Yellow' } default { 'Red' } }
        Write-Host ("    [{0,-8}] " -f $t.risk) -ForegroundColor $rc -NoNewline; Write-Host (Get-LocalizedText $t.name)
    }
    if (-not $Silent) {
        $a = Read-Host ('  ' + (Get-ForgeString 'prompt.confirm' @($selection.Count)))
        if ($a -notmatch '^[yYтТ]') { exit 0 }
    }
    $res = Invoke-ForgeSession -Tweaks $selection -Label $label -Profile $Profile -NoRestorePoint:($NoRestorePoint -or -not $config.createRestorePoint) -DefaultUser:$DefaultUser
    if ($Persist -eq 'on') { Register-ForgePersist -Ids @($selection.id) -Profile $Profile | Out-Null }
    elseif ($Persist -eq 'off') { Unregister-ForgePersist }
    $config.lastProfile = $Profile; Save-ForgeConfig $config
    if ($res -and $res.Reboot -and -not $Silent) {
        $a = Read-Host '  Reboot now? [y/N]'; if ($a -match '^[yYтТ]') { Restart-Computer -Force }
    }
    exit 0
}

if ($Persist -eq 'off') { Unregister-ForgePersist; exit 0 }

# ---------------------------------------------------------------- interactive
if ($Cli -or -not $IsWinHost) {
    . (Join-Path $script:Root 'src\WinForge.Tui.ps1')
    Show-Banner
    Start-ForgeTui
    exit 0
}
try {
    . (Join-Path $script:Root 'src\WinForge.Gui.ps1')
    Start-ForgeGui
} catch {
    Write-ForgeLog "GUI failed to start ($($_.Exception.Message)); falling back to console menu" -Level Warn
    . (Join-Path $script:Root 'src\WinForge.Tui.ps1')
    Show-Banner
    Start-ForgeTui
}
