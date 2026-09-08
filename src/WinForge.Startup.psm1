#Requires -Version 5.1
<#
    WinForge.Startup — startup manager: Run keys (HKCU/HKLM/WOW64), Startup folders, UWP StartupTasks.
    Enable/disable uses the same StartupApproved mechanism as Task Manager, journaled for undo.
#>
Set-StrictMode -Version 2.0

$script:Sources = @(
    @{ Location = 'HKCU Run';   Key = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run';             Approved = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' }
    @{ Location = 'HKLM Run';   Key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run';             Approved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' }
    @{ Location = 'HKLM Run32'; Key = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Approved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32' }
)

function Test-ApprovedEnabled {
    param([string]$ApprovedKey, [string]$Name)
    $v = Get-RegistryValueSafe -Path $ApprovedKey -Name $Name
    if (-not $v -or -not $v.Value) { return $true }
    $b = [byte[]]$v.Value
    return ($b.Length -eq 0 -or ($b[0] % 2) -eq 0)   # 02/06 = enabled, 03/07 = disabled
}

function Get-ForgeStartupItem {
    <# Returns every startup entry with Enabled state. Cross-platform safe (empty on non-Windows). #>
    [CmdletBinding()] param()
    if ($env:OS -ne 'Windows_NT') { return @() }
    $items = New-Object System.Collections.ArrayList
    foreach ($s in $script:Sources) {
        $k = Get-Item -LiteralPath $s.Key -ErrorAction SilentlyContinue
        if (-not $k) { continue }
        foreach ($n in $k.GetValueNames()) {
            if (-not $n) { continue }
            [void]$items.Add([PSCustomObject]@{ Kind = 'run'; Name = $n; Command = [string]$k.GetValue($n); Location = $s.Location; Enabled = (Test-ApprovedEnabled $s.Approved $n); Approved = $s.Approved; Key = $s.Key })
        }
    }
    $folders = @(
        @{ Location = 'Startup folder (user)'; Path = [Environment]::GetFolderPath('Startup');       Approved = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder' }
        @{ Location = 'Startup folder (all users)'; Path = [Environment]::GetFolderPath('CommonStartup'); Approved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder' }
    )
    foreach ($f in $folders) {
        if (-not $f.Path -or -not (Test-Path -LiteralPath $f.Path)) { continue }
        foreach ($file in Get-ChildItem -LiteralPath $f.Path -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' }) {
            $target = $file.FullName
            if ($file.Extension -eq '.lnk') { try { $target = (New-Object -ComObject WScript.Shell).CreateShortcut($file.FullName).TargetPath } catch { } }
            [void]$items.Add([PSCustomObject]@{ Kind = 'folder'; Name = $file.Name; Command = $target; Location = $f.Location; Enabled = (Test-ApprovedEnabled $f.Approved $file.Name); Approved = $f.Approved; Key = $f.Path })
        }
    }
    $uwpRoot = 'HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData'
    foreach ($pkg in Get-ChildItem -LiteralPath $uwpRoot -ErrorAction SilentlyContinue) {
        foreach ($task in Get-ChildItem -LiteralPath $pkg.PSPath -ErrorAction SilentlyContinue) {
            $state = (Get-ItemProperty -LiteralPath $task.PSPath -Name State -ErrorAction SilentlyContinue).State
            if ($null -eq $state) { continue }
            [void]$items.Add([PSCustomObject]@{ Kind = 'uwp'; Name = ($pkg.PSChildName -split '_')[0]; Command = "StartupTask $($task.PSChildName)"; Location = 'Store app'; Enabled = ($state -in @(2, 3)); Approved = ($task.PSPath -replace '^Microsoft\.PowerShell\.Core\\Registry::', ''); Key = $pkg.PSChildName })
        }
    }
    return @($items | Sort-Object Location, Name)
}

function ConvertTo-ApprovedBytes {
    param([bool]$Enabled)
    $b = New-Object byte[] 12
    $b[0] = if ($Enabled) { 2 } else { 3 }
    if (-not $Enabled) { $ft = [BitConverter]::GetBytes([DateTime]::UtcNow.ToFileTimeUtc()); [Array]::Copy($ft, 0, $b, 4, 8) }
    return $b
}

function Set-ForgeStartupItem {
    <# Enable/disable one item returned by Get-ForgeStartupItem. Journaled under tweak id "startup.<name>". #>
    [CmdletBinding()] param([Parameter(Mandatory)]$Item, [Parameter(Mandatory)][bool]$Enabled)
    $id = 'startup.' + ($Item.Name -replace '[^A-Za-z0-9\-]', '-').ToLower()
    if ($Item.Kind -eq 'uwp') {
        $path = $Item.Approved -replace '^HKEY_CURRENT_USER\\', 'HKCU:\'
        Set-ForgeRegistry -TweakId $id -Path $path -Name 'State' -Value $(if ($Enabled) { 2 } else { 1 }) -Kind DWord
    } else {
        $bytes = ConvertTo-ApprovedBytes -Enabled $Enabled
        Set-ForgeRegistry -TweakId $id -Path $Item.Approved -Name $Item.Name -Value $bytes -Kind Binary
    }
    Write-ForgeLog "startup: $($Item.Name) -> $(if ($Enabled) { 'enabled' } else { 'disabled' })" -Level Ok
}

function Disable-ForgeStartupItem { [CmdletBinding()] param([Parameter(Mandatory)]$Item) Set-ForgeStartupItem -Item $Item -Enabled $false }
function Enable-ForgeStartupItem  { [CmdletBinding()] param([Parameter(Mandatory)]$Item) Set-ForgeStartupItem -Item $Item -Enabled $true }

Export-ModuleMember -Function Get-ForgeStartupItem, Set-ForgeStartupItem, Disable-ForgeStartupItem, Enable-ForgeStartupItem, ConvertTo-ApprovedBytes
