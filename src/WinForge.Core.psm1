#Requires -Version 5.1
<#
    WinForge.Core — the engine.
    Responsibilities: logging, paths, config, journal (undo), primitive actions
    (registry / service / scheduled task / appx / feature / command / powershell),
    restore points, elevation helpers, default-user hive handling.

    Every "apply" of an action records the previous state into the current
    journal so that any tweak can be reverted even if it has no explicit revert.
#>

Set-StrictMode -Version 2.0

# ------------------------------------------------------------------ constants
$script:AppName    = 'WinForge'
$script:Version    = '1.2.1'
$script:IsWin      = ($env:OS -eq 'Windows_NT')
$script:RootDir    = Split-Path -Parent $PSScriptRoot
$script:DataDir    = if ($script:IsWin) { Join-Path $env:ProgramData $script:AppName } else { Join-Path $HOME ".$($script:AppName.ToLower())" }
$script:LogDir     = Join-Path $script:DataDir 'logs'
$script:JournalDir = Join-Path $script:DataDir 'journal'
$script:BackupDir  = Join-Path $script:DataDir 'backup'
$script:ConfigFile = Join-Path $script:DataDir 'config.json'
$script:LogFile    = $null
$script:Journal    = $null          # current session journal (PSCustomObject)
$script:DryRun     = $false
$script:Quiet      = $false
$script:UiSink     = $null          # optional scriptblock receiving log lines (GUI)
$script:DefaultUserLoaded = $false

foreach ($d in @($script:DataDir, $script:LogDir, $script:JournalDir, $script:BackupDir)) {
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

# ------------------------------------------------------------------ logging
function Initialize-ForgeLog {
    [CmdletBinding()] param([string]$Name = 'session')
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $script:LogFile = Join-Path $script:LogDir "$Name-$stamp.log"
    "# $($script:AppName) $($script:Version) — $(Get-Date -Format o)" | Set-Content -LiteralPath $script:LogFile -Encoding UTF8
    return $script:LogFile
}

function Write-ForgeLog {
    <#
    .SYNOPSIS Write a line to console + log file + optional GUI sink.
    .PARAMETER Level  Info | Ok | Warn | Error | Debug | Step
    #>
    [CmdletBinding()] param(
        [Parameter(Mandatory, Position = 0)][AllowEmptyString()][string]$Message,
        [ValidateSet('Info', 'Ok', 'Warn', 'Error', 'Debug', 'Step')][string]$Level = 'Info'
    )
    $time = Get-Date -Format 'HH:mm:ss'
    $line = "[$time] [$($Level.ToUpper().PadRight(5))] $Message"
    if ($script:LogFile) { Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 }
    if ($script:UiSink) { try { & $script:UiSink $Level $Message } catch { } }
    if ($script:Quiet -and $Level -notin 'Error', 'Warn') { return }
    if ($Level -eq 'Debug' -and -not $env:WINFORGE_DEBUG) { return }
    $color = switch ($Level) {
        'Ok'    { 'Green' }
        'Warn'  { 'Yellow' }
        'Error' { 'Red' }
        'Debug' { 'DarkGray' }
        'Step'  { 'Cyan' }
        default { 'Gray' }
    }
    $prefix = switch ($Level) {
        'Ok'    { '  [+] ' }
        'Warn'  { '  [!] ' }
        'Error' { '  [x] ' }
        'Step'  { '==> ' }
        'Debug' { '      ' }
        default { '  [*] ' }
    }
    Write-Host ($prefix + $Message) -ForegroundColor $color
}

function Set-ForgeUiSink { param([scriptblock]$Sink) $script:UiSink = $Sink }
function Set-ForgeDryRun { param([bool]$Enabled) $script:DryRun = $Enabled }
function Get-ForgeDryRun { return $script:DryRun }
function Set-ForgeQuiet  { param([bool]$Enabled) $script:Quiet = $Enabled }

function Get-ForgePaths {
    [PSCustomObject]@{
        Root = $script:RootDir; Data = $script:DataDir; Logs = $script:LogDir
        Journal = $script:JournalDir; Backup = $script:BackupDir; Config = $script:ConfigFile
        Log = $script:LogFile; Version = $script:Version
    }
}

# ------------------------------------------------------------------ config
function Get-ForgeConfig {
    $defaults = [ordered]@{
        language        = 'en'
        theme           = 'dark'
        createRestorePoint = $true
        confirmRisky    = $true
        telemetryScoreOnStart = $true
        lastProfile     = ''
        persistEnabled  = $false
        checkUpdates    = $true
    }
    if (Test-Path -LiteralPath $script:ConfigFile) {
        try {
            $saved = Get-Content -LiteralPath $script:ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($p in $saved.PSObject.Properties) { $defaults[$p.Name] = $p.Value }
        } catch { Write-ForgeLog "Config unreadable, using defaults: $($_.Exception.Message)" -Level Warn }
    }
    return [PSCustomObject]$defaults
}

function Save-ForgeConfig {
    param([Parameter(Mandatory)]$Config)
    $Config | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $script:ConfigFile -Encoding UTF8
}

# ------------------------------------------------------------------ environment
function Test-ForgeAdmin {
    if (-not $script:IsWin) { return $false }
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-ForgeOsInfo {
    <# Returns build number, UBR, edition, display version, arch, etc. Works cross-platform for tests (returns nulls). #>
    if (-not $script:IsWin) {
        return [PSCustomObject]@{ Build = 0; Ubr = 0; Edition = 'N/A'; DisplayVersion = 'N/A'; ProductName = 'N/A'; Arch = 'N/A'; IsWindows11 = $false; FullBuild = '0.0'; IsServer = $false }
    }
    $cv = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $build = [int]$cv.CurrentBuildNumber
    $ubr   = [int]($cv.UBR)
    [PSCustomObject]@{
        Build          = $build
        Ubr            = $ubr
        FullBuild      = "$build.$ubr"
        Edition        = $cv.EditionID
        DisplayVersion = if ($cv.PSObject.Properties['DisplayVersion']) { $cv.DisplayVersion } else { $cv.ReleaseId }
        ProductName    = if ($build -ge 22000) { ($cv.ProductName -replace 'Windows 10', 'Windows 11') } else { $cv.ProductName }
        Arch           = $env:PROCESSOR_ARCHITECTURE
        IsWindows11    = ($build -ge 22000)
        IsServer       = ($cv.InstallationType -eq 'Server')
    }
}

# ------------------------------------------------------------------ journal (undo)
function New-ForgeJournal {
    [CmdletBinding()] param([string]$Label = 'session', [string]$Profile = '')
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $script:Journal = [PSCustomObject]@{
        id       = "$stamp-$Label"
        created  = (Get-Date -Format o)
        label    = $Label
        profile  = $Profile
        version  = $script:Version
        dryRun   = $script:DryRun
        tweaks   = New-Object System.Collections.ArrayList   # { id, name, status, entries[] }
    }
    return $script:Journal
}

function Get-ForgeJournal { return $script:Journal }

function Save-ForgeJournal {
    if (-not $script:Journal -or $script:DryRun) { return $null }
    if ($script:Journal.tweaks.Count -eq 0) { return $null }
    $file = Join-Path $script:JournalDir "$($script:Journal.id).json"
    $script:Journal | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $file -Encoding UTF8
    return $file
}

function Get-ForgeJournalList {
    Get-ChildItem -LiteralPath $script:JournalDir -Filter '*.json' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | ForEach-Object {
            try {
                $j = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                [PSCustomObject]@{ Id = $j.id; Created = $j.created; Label = $j.label; Profile = $j.profile; Tweaks = @($j.tweaks).Count; File = $_.FullName }
            } catch { }
        }
}

function Add-JournalEntry {
    <# Records one reversible primitive. Called by the primitive actions after capturing "before" state. #>
    param([Parameter(Mandatory)][string]$TweakId, [Parameter(Mandatory)][hashtable]$Entry)
    if (-not $script:Journal) { New-ForgeJournal | Out-Null }
    $t = $script:Journal.tweaks | Where-Object { $_.id -eq $TweakId } | Select-Object -First 1
    if (-not $t) {
        $t = [PSCustomObject]@{ id = $TweakId; status = 'applied'; entries = New-Object System.Collections.ArrayList }
        [void]$script:Journal.tweaks.Add($t)
    }
    [void]$t.entries.Add([PSCustomObject]$Entry)
}

# ------------------------------------------------------------------ registry primitives
function ConvertTo-RegistryKind {
    param([string]$Kind)
    switch -Regex ($Kind) {
        '^(dword|int|reg_dword)$'       { return 'DWord' }
        '^(qword|long|reg_qword)$'      { return 'QWord' }
        '^(string|sz|reg_sz)$'          { return 'String' }
        '^(expand|expandstring|reg_expand_sz)$' { return 'ExpandString' }
        '^(multi|multistring|reg_multi_sz)$'    { return 'MultiString' }
        '^(binary|bin|reg_binary)$'     { return 'Binary' }
        default                          { return 'DWord' }
    }
}

function Resolve-RegistryPath {
    <# Accepts HKLM:\..., HKCU:\..., HKEY_LOCAL_MACHINE\..., HKU:\... and normalises to provider path. #>
    param([Parameter(Mandatory)][string]$Path)
    $p = $Path.Trim()
    $p = $p -replace '^HKEY_LOCAL_MACHINE\\', 'HKLM:\' -replace '^HKEY_CURRENT_USER\\', 'HKCU:\' `
            -replace '^HKEY_CLASSES_ROOT\\', 'HKCR:\' -replace '^HKEY_USERS\\', 'HKU:\' -replace '^HKEY_CURRENT_CONFIG\\', 'HKCC:\'
    if ($p -match '^HKLM\\') { $p = $p -replace '^HKLM\\', 'HKLM:\' }
    if ($p -match '^HKCU\\') { $p = $p -replace '^HKCU\\', 'HKCU:\' }
    if ($p -match '^HKCR\\') { $p = $p -replace '^HKCR\\', 'HKCR:\' }
    if ($p -match '^HKU\\')  { $p = $p -replace '^HKU\\',  'HKU:\' }
    return $p
}

function Confirm-RegistryDrives {
    if (-not $script:IsWin) { return }
    if (-not (Get-PSDrive -Name HKCR -ErrorAction SilentlyContinue)) { New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -Scope Global | Out-Null }
    if (-not (Get-PSDrive -Name HKU  -ErrorAction SilentlyContinue)) { New-PSDrive -Name HKU  -PSProvider Registry -Root HKEY_USERS -Scope Global | Out-Null }
}

function Get-RegistryValueSafe {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Name)
    $p = Resolve-RegistryPath $Path
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    $item = Get-Item -LiteralPath $p -ErrorAction SilentlyContinue
    if (-not $item) { return $null }
    if ($Name -eq '(Default)' -or $Name -eq '') { $Name = '' }
    $names = $item.GetValueNames()
    if ($names -notcontains $Name) { return $null }
    $kind = $item.GetValueKind($Name).ToString()
    $val  = $item.GetValue($Name, $null, 'DoNotExpandEnvironmentNames')
    [PSCustomObject]@{ Path = $p; Name = $Name; Kind = $kind; Value = $val }
}

function Set-ForgeRegistry {
    <#
    .SYNOPSIS Set a registry value (creating the key), journaling the previous state.
    #>
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$TweakId,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][AllowNull()]$Value,
        [string]$Kind = 'DWord'
    )
    Confirm-RegistryDrives
    $p = Resolve-RegistryPath $Path
    $k = ConvertTo-RegistryKind $Kind
    $before = Get-RegistryValueSafe -Path $p -Name $Name
    $keyExisted = Test-Path -LiteralPath $p
    Write-ForgeLog "reg  $p!$Name = $Value ($k)" -Level Debug
    if ($script:DryRun) { Write-ForgeLog "[dry] reg set $p!$Name = $Value" -Level Info; return }
    if (-not $keyExisted) { New-Item -Path $p -Force | Out-Null }
    if ($k -eq 'Binary' -and $Value -is [string]) { $Value = [byte[]]($Value -split '[ ,]' | Where-Object { $_ } | ForEach-Object { [Convert]::ToByte($_, 16) }) }
    if ($k -eq 'MultiString' -and $Value -isnot [array]) { $Value = @([string]$Value) }
    New-ItemProperty -LiteralPath $p -Name $Name -Value $Value -PropertyType $k -Force | Out-Null
    Add-JournalEntry -TweakId $TweakId -Entry @{
        type = 'registry'; path = $p; name = $Name; keyExisted = $keyExisted
        before = if ($before) { @{ kind = $before.Kind; value = $before.Value } } else { $null }
        after  = @{ kind = $k; value = $Value }
    }
}

function Remove-ForgeRegistryValue {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$TweakId, [Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Name)
    Confirm-RegistryDrives
    $p = Resolve-RegistryPath $Path
    $before = Get-RegistryValueSafe -Path $p -Name $Name
    if (-not $before) { Write-ForgeLog "reg  $p!$Name already absent" -Level Debug; return }
    if ($script:DryRun) { Write-ForgeLog "[dry] reg delete $p!$Name" -Level Info; return }
    Remove-ItemProperty -LiteralPath $p -Name $Name -Force -ErrorAction Stop
    Add-JournalEntry -TweakId $TweakId -Entry @{ type = 'registry'; path = $p; name = $Name; keyExisted = $true; before = @{ kind = $before.Kind; value = $before.Value }; after = $null }
}

function Remove-ForgeRegistryKey {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$TweakId, [Parameter(Mandatory)][string]$Path)
    Confirm-RegistryDrives
    $p = Resolve-RegistryPath $Path
    if (-not (Test-Path -LiteralPath $p)) { return }
    if ($script:DryRun) { Write-ForgeLog "[dry] reg delete key $p" -Level Info; return }
    # export to .reg for undo
    $safe = ($p -replace '[:\\]', '_')
    $bak  = Join-Path $script:BackupDir "$safe-$(Get-Date -Format 'yyyyMMddHHmmss').reg"
    $native = $p -replace '^HKLM:\\', 'HKEY_LOCAL_MACHINE\' -replace '^HKCU:\\', 'HKEY_CURRENT_USER\' -replace '^HKCR:\\', 'HKEY_CLASSES_ROOT\' -replace '^HKU:\\', 'HKEY_USERS\'
    & reg.exe export "$native" "$bak" /y | Out-Null
    Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop
    Add-JournalEntry -TweakId $TweakId -Entry @{ type = 'registryKey'; path = $p; backup = $bak }
}

function Restore-RegistryEntry {
    param($Entry)
    Confirm-RegistryDrives
    if ($Entry.type -eq 'registryKey') {
        if ($Entry.backup -and (Test-Path -LiteralPath $Entry.backup)) { & reg.exe import "$($Entry.backup)" | Out-Null }
        return
    }
    $p = $Entry.path
    if ($Entry.before) {
        if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force | Out-Null }
        $v = $Entry.before.value
        $k = $Entry.before.kind
        if ($k -eq 'Binary' -and $v -isnot [byte[]]) { $v = [byte[]]@($v | ForEach-Object { [byte]$_ }) }
        if ($k -eq 'MultiString' -and $v -isnot [array]) { $v = @([string]$v) }
        New-ItemProperty -LiteralPath $p -Name $Entry.name -Value $v -PropertyType $k -Force | Out-Null
    } else {
        if (Test-Path -LiteralPath $p) {
            Remove-ItemProperty -LiteralPath $p -Name $Entry.name -Force -ErrorAction SilentlyContinue
            if (-not $Entry.keyExisted) {
                $item = Get-Item -LiteralPath $p -ErrorAction SilentlyContinue
                if ($item -and $item.ValueCount -eq 0 -and $item.SubKeyCount -eq 0) { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue }
            }
        }
    }
}

# ------------------------------------------------------------------ default-user hive (sysprep / new accounts)
function Mount-DefaultUserHive {
    if (-not $script:IsWin -or $script:DefaultUserLoaded) { return $script:DefaultUserLoaded }
    $hive = Join-Path $env:SystemDrive 'Users\Default\NTUSER.DAT'
    if (-not (Test-Path -LiteralPath $hive)) { return $false }
    if ($script:DryRun) { return $true }
    $null = & reg.exe load 'HKU\WinForgeDefault' "$hive" 2>&1
    $script:DefaultUserLoaded = ($LASTEXITCODE -eq 0)
    return $script:DefaultUserLoaded
}
function Dismount-DefaultUserHive {
    if (-not $script:DefaultUserLoaded) { return }
    [gc]::Collect(); [gc]::WaitForPendingFinalizers()
    $null = & reg.exe unload 'HKU\WinForgeDefault' 2>&1
    $script:DefaultUserLoaded = $false
}

# ------------------------------------------------------------------ services
function Set-ForgeService {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$TweakId,
        [Parameter(Mandatory)][string]$Name,
        [ValidateSet('Automatic', 'AutomaticDelayed', 'Manual', 'Disabled')][string]$Startup = 'Disabled',
        [bool]$Stop = $true
    )
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) {
        # per-user services have a suffix like _1a2b3c
        $svc = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "$Name`_*" } | Select-Object -First 1
        if (-not $svc) { Write-ForgeLog "service $Name not found — skipped" -Level Debug; return }
    }
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($svc.Name)"
    $beforeStart = (Get-ItemProperty -LiteralPath $regPath -Name Start -ErrorAction SilentlyContinue).Start
    $beforeDelayed = (Get-ItemProperty -LiteralPath $regPath -Name DelayedAutostart -ErrorAction SilentlyContinue).DelayedAutostart
    $beforeStatus = $svc.Status.ToString()
    Write-ForgeLog "svc  $($svc.Name) -> $Startup (was Start=$beforeStart, $beforeStatus)" -Level Debug
    if ($script:DryRun) { Write-ForgeLog "[dry] service $($svc.Name) -> $Startup" -Level Info; return }
    $startValue = switch ($Startup) { 'Automatic' { 2 } 'AutomaticDelayed' { 2 } 'Manual' { 3 } 'Disabled' { 4 } }
    try {
        # Set-Service fails on protected services; fall back to registry (takes effect after reboot)
        if ($Startup -eq 'AutomaticDelayed') { & sc.exe config $svc.Name start= delayed-auto | Out-Null }
        else { Set-Service -Name $svc.Name -StartupType $Startup -ErrorAction Stop }
    } catch {
        Set-ItemProperty -LiteralPath $regPath -Name Start -Value $startValue -Type DWord -ErrorAction SilentlyContinue
    }
    if ($Stop -and $Startup -eq 'Disabled' -and $svc.Status -eq 'Running') {
        try { Stop-Service -Name $svc.Name -Force -ErrorAction Stop -WarningAction SilentlyContinue } catch { Write-ForgeLog "could not stop $($svc.Name) (will stop at reboot)" -Level Debug }
    }
    Add-JournalEntry -TweakId $TweakId -Entry @{ type = 'service'; name = $svc.Name; before = @{ start = $beforeStart; delayed = $beforeDelayed; status = $beforeStatus }; after = @{ start = $startValue } }
}

function Restore-ServiceEntry {
    param($Entry)
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($Entry.name)"
    if (-not (Test-Path -LiteralPath $regPath)) { return }
    if ($null -ne $Entry.before.start) {
        Set-ItemProperty -LiteralPath $regPath -Name Start -Value ([int]$Entry.before.start) -Type DWord -ErrorAction SilentlyContinue
        if ($null -ne $Entry.before.delayed) { Set-ItemProperty -LiteralPath $regPath -Name DelayedAutostart -Value ([int]$Entry.before.delayed) -Type DWord -ErrorAction SilentlyContinue }
        if ([int]$Entry.before.start -eq 2 -and $Entry.before.status -eq 'Running') { Start-Service -Name $Entry.name -ErrorAction SilentlyContinue }
    }
}

# ------------------------------------------------------------------ scheduled tasks
function Set-ForgeScheduledTask {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$TweakId,
        [Parameter(Mandatory)][string]$Path,     # e.g. \Microsoft\Windows\Application Experience\
        [Parameter(Mandatory)][string]$Name,
        [ValidateSet('Enabled', 'Disabled')][string]$State = 'Disabled'
    )
    if (-not $Path.EndsWith('\')) { $Path += '\' }
    $task = Get-ScheduledTask -TaskPath $Path -TaskName $Name -ErrorAction SilentlyContinue
    if (-not $task) { Write-ForgeLog "task $Path$Name not found — skipped" -Level Debug; return }
    $before = $task.State.ToString()
    Write-ForgeLog "task $Path$Name -> $State (was $before)" -Level Debug
    if ($script:DryRun) { Write-ForgeLog "[dry] task $Path$Name -> $State" -Level Info; return }
    try {
        if ($State -eq 'Disabled') { $task | Disable-ScheduledTask -ErrorAction Stop | Out-Null } else { $task | Enable-ScheduledTask -ErrorAction Stop | Out-Null }
    } catch {
        # schtasks fallback for tasks protected from the CIM API
        $flag = if ($State -eq 'Disabled') { '/Disable' } else { '/Enable' }
        & schtasks.exe /Change /TN "$Path$Name" $flag | Out-Null
    }
    Add-JournalEntry -TweakId $TweakId -Entry @{ type = 'task'; path = $Path; name = $Name; before = $before; after = $State }
}

function Restore-TaskEntry {
    param($Entry)
    $task = Get-ScheduledTask -TaskPath $Entry.path -TaskName $Entry.name -ErrorAction SilentlyContinue
    if (-not $task) { return }
    if ($Entry.before -eq 'Disabled') { $task | Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null }
    else { $task | Enable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null }
}

# ------------------------------------------------------------------ appx packages
function Get-ForgeAppxInventory {
    <# Inventory of installed (all users) + provisioned packages. Cached per call. #>
    if (-not $script:IsWin) { return @() }
    $installed = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    $names = @{}
    foreach ($p in $installed) { $names[$p.Name] = [PSCustomObject]@{ Name = $p.Name; Installed = $true; Provisioned = $false; Publisher = $p.Publisher; Version = $p.Version; NonRemovable = $p.NonRemovable; InstallLocation = $p.InstallLocation } }
    foreach ($p in $prov) {
        if ($names.ContainsKey($p.DisplayName)) { $names[$p.DisplayName].Provisioned = $true }
        else { $names[$p.DisplayName] = [PSCustomObject]@{ Name = $p.DisplayName; Installed = $false; Provisioned = $true; Publisher = ''; Version = $p.Version; NonRemovable = $false; InstallLocation = '' } }
    }
    return $names.Values | Sort-Object Name
}

function Remove-ForgeAppx {
    <#
    .SYNOPSIS Remove an AppX package for all users and de-provision it. Supports wildcards.
    #>
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$TweakId,
        [Parameter(Mandatory)][string]$Name,
        [bool]$AllUsers = $true,
        [bool]$Provisioned = $true
    )
    $removed = 0
    $pkgs = @()
    if ($AllUsers) { $pkgs = @(Get-AppxPackage -AllUsers -Name $Name -ErrorAction SilentlyContinue) }
    else { $pkgs = @(Get-AppxPackage -Name $Name -ErrorAction SilentlyContinue) }
    foreach ($pkg in $pkgs) {
        if ($pkg.NonRemovable) { Write-ForgeLog "appx $($pkg.Name) is NonRemovable — trying registry unlock" -Level Debug; Unblock-NonRemovableAppx -PackageFullName $pkg.PackageFullName }
        Write-ForgeLog "appx remove $($pkg.PackageFullName)" -Level Debug
        if ($script:DryRun) { Write-ForgeLog "[dry] appx remove $($pkg.Name)" -Level Info; $removed++; continue }
        try {
            if ($AllUsers) { Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop } else { Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop }
            $removed++
            Add-JournalEntry -TweakId $TweakId -Entry @{ type = 'appx'; name = $pkg.Name; fullName = $pkg.PackageFullName; installLocation = $pkg.InstallLocation; allUsers = $AllUsers }
        } catch { Write-ForgeLog "appx $($pkg.Name): $($_.Exception.Message.Split("`n")[0])" -Level Warn }
    }
    if ($Provisioned) {
        $provs = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $Name })
        foreach ($pp in $provs) {
            if ($script:DryRun) { Write-ForgeLog "[dry] appx deprovision $($pp.DisplayName)" -Level Info; continue }
            try {
                Remove-AppxProvisionedPackage -Online -PackageName $pp.PackageName -ErrorAction Stop | Out-Null
                Add-JournalEntry -TweakId $TweakId -Entry @{ type = 'appxProvisioned'; name = $pp.DisplayName; packageName = $pp.PackageName }
            } catch { Write-ForgeLog "deprovision $($pp.DisplayName): $($_.Exception.Message.Split("`n")[0])" -Level Warn }
        }
    }
    return $removed
}

function Unblock-NonRemovableAppx {
    param([string]$PackageFullName)
    # Windows marks some packages non-removable via this key; deleting the entry lets Remove-AppxPackage proceed.
    $base = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore'
    foreach ($sub in @('EndOfLife', 'Deprovisioned')) { }  # informational only
    $key = Join-Path $base "InboxApplications\$PackageFullName"
    if (Test-Path -LiteralPath $key) { if (-not $script:DryRun) { Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction SilentlyContinue } }
}

function Restore-AppxEntry {
    param($Entry)
    if ($Entry.type -eq 'appx' -and $Entry.installLocation -and (Test-Path -LiteralPath (Join-Path $Entry.installLocation 'AppxManifest.xml'))) {
        try { Add-AppxPackage -DisableDevelopmentMode -Register (Join-Path $Entry.installLocation 'AppxManifest.xml') -ErrorAction Stop; return $true } catch { }
    }
    # Fallback: ask winget / store
    try { Start-Process "ms-windows-store://pdp/?productid=" -ErrorAction SilentlyContinue } catch { }
    return $false
}

# ------------------------------------------------------------------ windows optional features / capabilities
function Set-ForgeWindowsFeature {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$TweakId,
        [Parameter(Mandatory)][string]$Name,
        [ValidateSet('Enabled', 'Disabled')][string]$State = 'Disabled',
        [ValidateSet('feature', 'capability')][string]$Kind = 'feature'
    )
    if ($Kind -eq 'feature') {
        $f = Get-WindowsOptionalFeature -Online -FeatureName $Name -ErrorAction SilentlyContinue
        if (-not $f) { Write-ForgeLog "feature $Name not present — skipped" -Level Debug; return }
        $before = $f.State.ToString()
        if ($before -like "$State*") { return }
        if ($script:DryRun) { Write-ForgeLog "[dry] feature $Name -> $State" -Level Info; return }
        if ($State -eq 'Disabled') { Disable-WindowsOptionalFeature -Online -FeatureName $Name -NoRestart -ErrorAction Stop | Out-Null }
        else { Enable-WindowsOptionalFeature -Online -FeatureName $Name -NoRestart -All -ErrorAction Stop | Out-Null }
    } else {
        $c = Get-WindowsCapability -Online -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "$Name*" } | Select-Object -First 1
        if (-not $c) { Write-ForgeLog "capability $Name not present — skipped" -Level Debug; return }
        $before = $c.State.ToString()
        if (($State -eq 'Disabled' -and $before -eq 'NotPresent') -or ($State -eq 'Enabled' -and $before -eq 'Installed')) { return }
        if ($script:DryRun) { Write-ForgeLog "[dry] capability $($c.Name) -> $State" -Level Info; return }
        if ($State -eq 'Disabled') { Remove-WindowsCapability -Online -Name $c.Name -ErrorAction Stop | Out-Null }
        else { Add-WindowsCapability -Online -Name $c.Name -ErrorAction Stop | Out-Null }
        $Name = $c.Name
    }
    Add-JournalEntry -TweakId $TweakId -Entry @{ type = 'feature'; kind = $Kind; name = $Name; before = $before; after = $State }
}

function Restore-FeatureEntry {
    param($Entry)
    $wantEnabled = ($Entry.before -like 'Enabled*' -or $Entry.before -eq 'Installed')
    if ($Entry.kind -eq 'feature') {
        if ($wantEnabled) { Enable-WindowsOptionalFeature -Online -FeatureName $Entry.name -NoRestart -All -ErrorAction SilentlyContinue | Out-Null }
        else { Disable-WindowsOptionalFeature -Online -FeatureName $Entry.name -NoRestart -ErrorAction SilentlyContinue | Out-Null }
    } else {
        if ($wantEnabled) { Add-WindowsCapability -Online -Name $Entry.name -ErrorAction SilentlyContinue | Out-Null }
        else { Remove-WindowsCapability -Online -Name $Entry.name -ErrorAction SilentlyContinue | Out-Null }
    }
}

# ------------------------------------------------------------------ commands / inline powershell
function Invoke-ForgeCommand {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$TweakId, [Parameter(Mandatory)][string]$Apply, [string]$Revert = '', [string]$Shell = 'cmd')
    Write-ForgeLog "cmd  $Apply" -Level Debug
    if ($script:DryRun) { Write-ForgeLog "[dry] $Apply" -Level Info; return }
    $out = if ($Shell -eq 'powershell') { Invoke-Expression $Apply 2>&1 } else { & cmd.exe /d /c $Apply 2>&1 }
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { Write-ForgeLog "exit $LASTEXITCODE : $Apply :: $($out | Select-Object -Last 1)" -Level Warn }
    Add-JournalEntry -TweakId $TweakId -Entry @{ type = 'command'; apply = $Apply; revert = $Revert; shell = $Shell }
}

function Restore-CommandEntry {
    param($Entry)
    if (-not $Entry.revert) { return }
    if ($Entry.shell -eq 'powershell') { Invoke-Expression $Entry.revert 2>&1 | Out-Null } else { & cmd.exe /d /c $Entry.revert 2>&1 | Out-Null }
}

# ------------------------------------------------------------------ restore point
function New-ForgeRestorePoint {
    [CmdletBinding()] param([string]$Description = "$($script:AppName) before tweaks")
    if (-not $script:IsWin -or $script:DryRun) { return $false }
    try {
        # Windows limits to one restore point per 24h unless this key is set
        $key = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
        if (-not (Test-Path -LiteralPath $key)) { New-Item -Path $key -Force | Out-Null }
        Set-ItemProperty -LiteralPath $key -Name 'SystemRestorePointCreationFrequency' -Value 0 -Type DWord -Force
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description $Description -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-ForgeLog "Restore point created: $Description" -Level Ok
        return $true
    } catch {
        Write-ForgeLog "Restore point failed: $($_.Exception.Message)" -Level Warn
        return $false
    }
}

# ------------------------------------------------------------------ revert by journal
function Restore-ForgeJournal {
    <#
    .SYNOPSIS Undo every entry in a journal file (newest entry first). Optionally only one tweak id.
    #>
    [CmdletBinding()] param([Parameter(Mandatory)][string]$File, [string]$TweakId = '')
    $j = Get-Content -LiteralPath $File -Raw -Encoding UTF8 | ConvertFrom-Json
    $tweaks = @($j.tweaks)
    if ($TweakId) { $tweaks = @($tweaks | Where-Object { $_.id -eq $TweakId }) }
    [array]::Reverse($tweaks)
    $count = 0
    $touchesDefault = @($tweaks | ForEach-Object { $_.entries } | Where-Object { $_.PSObject.Properties['path'] -and "$($_.path)" -like 'HKU:\WinForgeDefault\*' }).Count -gt 0
    if ($touchesDefault -and -not $script:DryRun) { Mount-DefaultUserHive | Out-Null }
    foreach ($t in $tweaks) {
        Write-ForgeLog "Reverting $($t.id)" -Level Step
        $entries = @($t.entries); [array]::Reverse($entries)
        foreach ($e in $entries) {
            if ($script:DryRun) { Write-ForgeLog "[dry] undo $($e.type) $($e.name)" -Level Info; continue }
            try {
                switch ($e.type) {
                    'registry'        { Restore-RegistryEntry $e }
                    'registryKey'     { Restore-RegistryEntry $e }
                    'service'         { Restore-ServiceEntry  $e }
                    'task'            { Restore-TaskEntry     $e }
                    'appx'            { Restore-AppxEntry     $e | Out-Null }
                    'appxProvisioned' { Write-ForgeLog "provisioned package $($e.name) cannot be re-provisioned automatically; reinstall from Microsoft Store" -Level Warn }
                    'feature'         { Restore-FeatureEntry  $e }
                    'command'         { Restore-CommandEntry  $e }
                }
                $count++
            } catch { Write-ForgeLog "undo failed for $($e.type) $($e.name): $($_.Exception.Message)" -Level Warn }
        }
    }
    if ($touchesDefault) { Dismount-DefaultUserHive }
    Write-ForgeLog "Reverted $count change(s) from $($j.id)" -Level Ok
    return $count
}

# ------------------------------------------------------------------ misc helpers
function Restart-ForgeExplorer {
    if (-not $script:IsWin -or $script:DryRun) { return }
    Write-ForgeLog 'Restarting Explorer to apply shell changes' -Level Info
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
}

function Get-ForgeSystemRestoreStatus {
    if (-not $script:IsWin) { return $false }
    try { $rp = Get-ComputerRestorePoint -ErrorAction Stop; return ($null -ne $rp) } catch { return $false }
}

Export-ModuleMember -Function *-Forge*, Get-RegistryValueSafe, Resolve-RegistryPath, ConvertTo-RegistryKind, Add-JournalEntry, Mount-DefaultUserHive, Dismount-DefaultUserHive, Confirm-RegistryDrives, Unblock-NonRemovableAppx -Variable @()
