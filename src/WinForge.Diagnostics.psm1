#Requires -Version 5.1
<#
    WinForge.Diagnostics — system inventory, health checks and the WinForge Score.
    The score is three 0-100 gauges (Privacy / Performance / Bloat) computed from
    the live state of catalog tweaks, so it moves as you apply things.
#>
Set-StrictMode -Version 2.0

function Get-ForgeHardwareInfo {
    if ($env:OS -ne 'Windows_NT') {
        return [PSCustomObject]@{ Cpu = 'N/A'; Cores = 0; Threads = 0; RamGB = 0; Gpu = @(); Disks = @(); Board = 'N/A'; Bios = 'N/A'; SecureBoot = $null; Vbs = $null; Laptop = $false; Uptime = [TimeSpan]::Zero; Hostname = [Environment]::MachineName }
    }
    $cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1
    $cs   = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS
    $bb   = Get-CimInstance Win32_BaseBoard
    $os   = Get-CimInstance Win32_OperatingSystem
    $gpus = @(Get-CimInstance Win32_VideoController | ForEach-Object {
        $vram = try { (Get-ItemProperty -LiteralPath "HKLM:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0*" -Name 'HardwareInformation.qwMemorySize' -ErrorAction SilentlyContinue | Where-Object { $_ } | Select-Object -First 1).'HardwareInformation.qwMemorySize' } catch { $null }
        [PSCustomObject]@{ Name = $_.Name; Driver = $_.DriverVersion; VramGB = if ($vram) { [math]::Round($vram / 1GB, 1) } elseif ($_.AdapterRAM) { [math]::Round($_.AdapterRAM / 1GB, 1) } else { 0 }
                           Vendor = if ($_.Name -match 'NVIDIA') { 'NVIDIA' } elseif ($_.Name -match 'AMD|Radeon') { 'AMD' } elseif ($_.Name -match 'Intel') { 'Intel' } else { 'Other' } }
    })
    $disks = @(Get-PhysicalDisk -ErrorAction SilentlyContinue | ForEach-Object { [PSCustomObject]@{ Name = $_.FriendlyName; Type = $_.MediaType; Bus = $_.BusType; SizeGB = [math]::Round($_.Size / 1GB) ; Health = $_.HealthStatus } })
    $sb = try { Confirm-SecureBootUEFI -ErrorAction Stop } catch { $null }
    $vbs = try { (Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction Stop).VirtualizationBasedSecurityStatus -eq 2 } catch { $null }
    $laptop = ($cs.PCSystemType -eq 2) -or ($null -ne (Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue))
    [PSCustomObject]@{
        Cpu = $cpu.Name.Trim(); Cores = $cpu.NumberOfCores; Threads = $cpu.NumberOfLogicalProcessors
        RamGB = [math]::Round($cs.TotalPhysicalMemory / 1GB); Gpu = $gpus; Disks = $disks
        Board = "$($bb.Manufacturer) $($bb.Product)".Trim(); Bios = "$($bios.SMBIOSBIOSVersion)"
        SecureBoot = $sb; Vbs = $vbs; Laptop = $laptop; Uptime = ((Get-Date) - $os.LastBootUpTime); Hostname = $cs.Name
        SystemDriveFreeGB = [math]::Round((Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':'))).Free / 1GB, 1)
    }
}

function Get-ForgeRuntimeStats {
    <# Things that make a PC feel slow: process count, running services, startup entries, bloat apps installed. #>
    if ($env:OS -ne 'Windows_NT') { return [PSCustomObject]@{ Processes = 0; RunningServices = 0; StartupEntries = 0; AppxCount = 0; RamUsedPct = 0 } }
    $os = Get-CimInstance Win32_OperatingSystem
    $startup = 0
    foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run') {
        $i = Get-Item -LiteralPath $k -ErrorAction SilentlyContinue; if ($i) { $startup += $i.ValueCount }
    }
    $startup += @(Get-ChildItem -LiteralPath ([Environment]::GetFolderPath('Startup')) -ErrorAction SilentlyContinue).Count
    [PSCustomObject]@{
        Processes       = (Get-Process).Count
        RunningServices = @(Get-Service | Where-Object Status -eq 'Running').Count
        StartupEntries  = $startup
        AppxCount       = @(Get-AppxPackage -ErrorAction SilentlyContinue).Count
        RamUsedPct      = [math]::Round(100 - ($os.FreePhysicalMemory / $os.TotalVisibleMemorySize * 100))
    }
}

function Get-ForgeScore {
    <#
    .SYNOPSIS Compute Privacy / Performance / Bloat scores (0-100) from live tweak state.
      Each tweak carries an optional "weight" (default 1). Category → gauge mapping below.
    #>
    [CmdletBinding()] param([object[]]$Catalog = (Import-ForgeCatalog), [hashtable]$StateCache = $null)
    $map = @{
        privacy = 'Privacy'; ai = 'Privacy'; edge = 'Privacy'; security = 'Privacy'
        performance = 'Performance'; gaming = 'Performance'; services = 'Performance'; power = 'Performance'; network = 'Performance'
        bloatware = 'Bloat'; ui = 'Bloat'; explorer = 'Bloat'; updates = 'Bloat'
    }
    $tot = @{ Privacy = 0.0; Performance = 0.0; Bloat = 0.0 }
    $got = @{ Privacy = 0.0; Performance = 0.0; Bloat = 0.0 }
    foreach ($t in $Catalog) {
        if ($t.risk -eq 'advanced') { continue }              # advanced tweaks are opt-in, never counted against you
        $gauge = $map[$t.category]; if (-not $gauge) { continue }
        $w = if ($t.PSObject.Properties['weight'] -and $t.weight) { [double]$t.weight } else { 1.0 }
        $state = if ($StateCache -and $StateCache.ContainsKey($t.id)) { $StateCache[$t.id] } else { Get-ForgeTweakState -Tweak $t }
        if ($state -eq 'Unknown') { continue }
        $tot[$gauge] += $w
        if ($state -eq 'Applied') { $got[$gauge] += $w } elseif ($state -eq 'Partial') { $got[$gauge] += $w / 2 }
    }
    $r = [ordered]@{}
    foreach ($g in 'Privacy', 'Performance', 'Bloat') { $r[$g] = if ($tot[$g] -gt 0) { [int][math]::Round($got[$g] / $tot[$g] * 100) } else { 0 } }
    $r['Overall'] = [int][math]::Round(($r.Privacy + $r.Performance + $r.Bloat) / 3)
    return [PSCustomObject]$r
}

function Get-ForgeStateMap {
    <# Evaluate every tweak's state once (slow-ish: DISM/Appx calls) and return a hashtable id → state. #>
    [CmdletBinding()] param([object[]]$Catalog = (Import-ForgeCatalog), [scriptblock]$Progress = $null)
    $h = @{}
    $i = 0; $n = $Catalog.Count
    foreach ($t in $Catalog) {
        $i++
        if ($Progress) { & $Progress $i $n $t }
        $h[$t.id] = Get-ForgeTweakState -Tweak $t
    }
    return $h
}

function Get-ForgeHealthReport {
    <# One object for the dashboard / -Status output. #>
    [CmdletBinding()] param([switch]$SkipScore)
    $os = Get-ForgeOsInfo
    $hw = Get-ForgeHardwareInfo
    $rt = Get-ForgeRuntimeStats
    $score = if ($SkipScore) { $null } else { Get-ForgeScore }
    [PSCustomObject]@{ Os = $os; Hardware = $hw; Runtime = $rt; Score = $score; RestorePoints = (Get-ForgeSystemRestoreStatus); Admin = (Test-ForgeAdmin); Generated = (Get-Date -Format o) }
}

function Get-ForgeCleanupTargets {
    <# Sizes of junk folders (for the Cleaner page). Read-only. #>
    if ($env:OS -ne 'Windows_NT') { return @() }
    $targets = @(
        @{ Id = 'temp';      Name = 'User temp';             Path = $env:TEMP }
        @{ Id = 'wintemp';   Name = 'Windows temp';          Path = (Join-Path $env:SystemRoot 'Temp') }
        @{ Id = 'prefetch';  Name = 'Prefetch';              Path = (Join-Path $env:SystemRoot 'Prefetch') }
        @{ Id = 'wudl';      Name = 'Windows Update cache';  Path = (Join-Path $env:SystemRoot 'SoftwareDistribution\Download') }
        @{ Id = 'thumbs';    Name = 'Thumbnail cache';       Path = (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer'); Filter = 'thumbcache_*.db' }
        @{ Id = 'crash';     Name = 'Crash dumps';           Path = (Join-Path $env:LOCALAPPDATA 'CrashDumps') }
        @{ Id = 'dodl';      Name = 'Delivery Optimization'; Path = (Join-Path $env:SystemRoot 'ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache') }
        @{ Id = 'wer';       Name = 'Error reports';         Path = (Join-Path $env:ProgramData 'Microsoft\Windows\WER') }
        @{ Id = 'logs';      Name = 'Windows logs (CBS/DISM)'; Path = (Join-Path $env:SystemRoot 'Logs') }
        @{ Id = 'recycle';   Name = 'Recycle Bin';           Path = 'shell:RecycleBin' }
    )
    foreach ($t in $targets) {
        $size = 0
        if ($t.Id -eq 'recycle') {
            try { $sh = New-Object -ComObject Shell.Application; $rb = $sh.Namespace(0xA); foreach ($it in $rb.Items()) { $size += $it.Size } } catch { }
        } elseif (Test-Path -LiteralPath $t.Path) {
            $f = if ($t.ContainsKey('Filter')) { $t.Filter } else { '*' }
            $size = (Get-ChildItem -LiteralPath $t.Path -Filter $f -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            if (-not $size) { $size = 0 }
        }
        [PSCustomObject]@{ Id = $t.Id; Name = $t.Name; Path = $t.Path; Bytes = [long]$size; MB = [math]::Round($size / 1MB, 1) }
    }
}

function Invoke-ForgeCleanup {
    [CmdletBinding()] param([string[]]$Ids = @('temp', 'wintemp', 'prefetch', 'wudl', 'thumbs', 'crash', 'dodl', 'wer', 'recycle'))
    $freed = 0L
    foreach ($t in (Get-ForgeCleanupTargets | Where-Object { $Ids -contains $_.Id })) {
        if (Get-ForgeDryRun) { Write-ForgeLog "[dry] clean $($t.Name) ($($t.MB) MB)" -Level Info; $freed += $t.Bytes; continue }
        try {
            switch ($t.Id) {
                'recycle' { Clear-RecycleBin -Force -ErrorAction SilentlyContinue }
                'wudl'    { Stop-Service wuauserv -Force -ErrorAction SilentlyContinue; Remove-Item -LiteralPath $t.Path -Recurse -Force -ErrorAction SilentlyContinue; Start-Service wuauserv -ErrorAction SilentlyContinue }
                'thumbs'  { Get-ChildItem -LiteralPath $t.Path -Filter 'thumbcache_*.db' -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue }
                default   { Get-ChildItem -LiteralPath $t.Path -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }
            }
            $freed += $t.Bytes
            Write-ForgeLog "cleaned $($t.Name): $($t.MB) MB" -Level Ok
        } catch { Write-ForgeLog "clean $($t.Name): $($_.Exception.Message)" -Level Warn }
    }
    return [math]::Round($freed / 1MB, 1)
}

Export-ModuleMember -Function *-Forge*
