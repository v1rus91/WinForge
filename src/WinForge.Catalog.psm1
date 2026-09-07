#Requires -Version 5.1
<#
    WinForge.Catalog — declarative tweak catalog.
    Tweaks live in /catalog/*.json, profiles in /profiles/*.json.
    This module loads, validates, filters by OS build/edition, detects current
    state, and applies / reverts tweaks by dispatching to WinForge.Core primitives.
#>
Set-StrictMode -Version 2.0

$script:Catalog  = $null      # array of tweak objects
$script:Profiles = $null
$script:Lang     = 'en'
$script:Strings  = @{}
$script:RootDir  = Split-Path -Parent $PSScriptRoot

$script:ValidRisk    = @('safe', 'moderate', 'advanced')
$script:ValidActions = @('registry', 'registryDelete', 'registryDeleteKey', 'service', 'task', 'appx', 'feature', 'capability', 'command', 'powershell')
$script:Categories   = [ordered]@{
    privacy     = @{ icon = [char]::ConvertFromUtf32(0x1F512); order = 1 }
    ai          = @{ icon = [char]::ConvertFromUtf32(0x1F916); order = 2 }
    bloatware   = @{ icon = [char]::ConvertFromUtf32(0x1F9F9); order = 3 }
    performance = @{ icon = [char]::ConvertFromUtf32(0x26A1);  order = 4 }
    gaming      = @{ icon = [char]::ConvertFromUtf32(0x1F3AE); order = 5 }
    services    = @{ icon = [char]::ConvertFromUtf32(0x2699);  order = 6 }
    ui          = @{ icon = [char]::ConvertFromUtf32(0x1F3A8); order = 7 }
    explorer    = @{ icon = [char]::ConvertFromUtf32(0x1F4C1); order = 8 }
    edge        = @{ icon = [char]::ConvertFromUtf32(0x1F310); order = 9 }
    updates     = @{ icon = [char]::ConvertFromUtf32(0x1F504); order = 10 }
    network     = @{ icon = [char]::ConvertFromUtf32(0x1F4E1); order = 11 }
    security    = @{ icon = [char]::ConvertFromUtf32(0x1F6E1); order = 12 }
    power       = @{ icon = [char]::ConvertFromUtf32(0x1F50B); order = 13 }
    advanced    = @{ icon = [char]::ConvertFromUtf32(0x1F9EA); order = 14 }
}

# ------------------------------------------------------------------ i18n
function Set-ForgeLanguage {
    param([string]$Language = 'en')
    $file = Join-Path $script:RootDir "src\i18n\$Language.json"
    if (-not (Test-Path -LiteralPath $file)) { $file = Join-Path $script:RootDir 'src/i18n/en.json' }
    $file = $file -replace '\\', [IO.Path]::DirectorySeparatorChar
    $script:Lang = $Language
    $script:Strings = @{}
    if (Test-Path -LiteralPath $file) {
        $obj = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($p in $obj.PSObject.Properties) { $script:Strings[$p.Name] = $p.Value }
    }
}
function Get-ForgeLanguage { return $script:Lang }
function Get-ForgeString {
    param([Parameter(Mandatory)][string]$Key, [object[]]$Format = @())
    $s = if ($script:Strings.ContainsKey($Key)) { $script:Strings[$Key] } else { $Key }
    if ($Format.Count -gt 0) { return ($s -f $Format) }
    return $s
}
function Get-LocalizedText {
    <# Tweak name/description may be a plain string or {en:..., uk:...} #>
    param($Value)
    if ($null -eq $Value) { return '' }
    if ($Value -is [string]) { return $Value }
    $props = $Value.PSObject.Properties
    if ($props[$script:Lang]) { return $props[$script:Lang].Value }
    if ($props['en']) { return $props['en'].Value }
    return [string]($props | Select-Object -First 1).Value
}

# ------------------------------------------------------------------ load & validate
function Import-ForgeCatalog {
    [CmdletBinding()] param([string]$Path = (Join-Path $script:RootDir 'catalog'), [switch]$Force)
    if ($script:Catalog -and -not $Force) { return $script:Catalog }
    $list = New-Object System.Collections.ArrayList
    $files = Get-ChildItem -LiteralPath $Path -Filter '*.json' | Sort-Object Name
    foreach ($f in $files) {
        $doc = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        $cat = $doc.category
        foreach ($t in $doc.tweaks) {
            if (-not $t.PSObject.Properties['category']) { $t | Add-Member -NotePropertyName category -NotePropertyValue $cat }
            $t | Add-Member -NotePropertyName sourceFile -NotePropertyValue $f.Name -Force
            [void]$list.Add($t)
        }
    }
    $script:Catalog = $list.ToArray()
    return $script:Catalog
}

function Test-ForgeCatalog {
    <# Returns an array of validation error strings (empty = valid). Used by Pester and the CLI. #>
    [CmdletBinding()] param([object[]]$Catalog = (Import-ForgeCatalog))
    $errors = New-Object System.Collections.ArrayList
    $seen = @{}
    foreach ($t in $Catalog) {
        $id = $t.id
        if (-not $id) { [void]$errors.Add("tweak without id in $($t.sourceFile)"); continue }
        if ($id -notmatch '^[a-z0-9]+(\.[a-z0-9\-]+)+$') { [void]$errors.Add("$id : id must be dotted lowercase (category.name)") }
        if ($seen.ContainsKey($id)) { [void]$errors.Add("$id : duplicate id (also in $($seen[$id]))") } else { $seen[$id] = $t.sourceFile }
        if (-not (Get-LocalizedText $t.name)) { [void]$errors.Add("$id : missing name") }
        if (-not (Get-LocalizedText $t.description)) { [void]$errors.Add("$id : missing description") }
        if ($t.category -notin $script:Categories.Keys) { [void]$errors.Add("$id : unknown category '$($t.category)'") }
        if ($t.risk -notin $script:ValidRisk) { [void]$errors.Add("$id : risk must be one of $($script:ValidRisk -join '|')") }
        if (-not $t.PSObject.Properties['actions'] -or @($t.actions).Count -eq 0) { [void]$errors.Add("$id : no actions") ; continue }
        $i = 0
        foreach ($a in $t.actions) {
            $i++
            if ($a.type -notin $script:ValidActions) { [void]$errors.Add("$id : action #$i unknown type '$($a.type)'"); continue }
            switch ($a.type) {
                'registry' {
                    foreach ($req in 'path', 'name') { if (-not $a.PSObject.Properties[$req]) { [void]$errors.Add("$id : action #$i registry missing '$req'") } }
                    if (-not $a.PSObject.Properties['value']) { [void]$errors.Add("$id : action #$i registry missing 'value'") }
                    if ($a.path -notmatch '^(HKLM|HKCU|HKCR|HKU|HKEY_LOCAL_MACHINE|HKEY_CURRENT_USER|HKEY_CLASSES_ROOT|HKEY_USERS)(:)?\\') { [void]$errors.Add("$id : action #$i bad registry path '$($a.path)'") }
                }
                'registryDelete'    { foreach ($req in 'path', 'name') { if (-not $a.PSObject.Properties[$req]) { [void]$errors.Add("$id : action #$i registryDelete missing '$req'") } } }
                'registryDeleteKey' { if (-not $a.PSObject.Properties['path']) { [void]$errors.Add("$id : action #$i registryDeleteKey missing 'path'") } }
                'service'    { if (-not $a.PSObject.Properties['name']) { [void]$errors.Add("$id : action #$i service missing 'name'") }
                               if ($a.PSObject.Properties['startup'] -and $a.startup -notin 'Automatic', 'AutomaticDelayed', 'Manual', 'Disabled') { [void]$errors.Add("$id : action #$i bad startup '$($a.startup)'") } }
                'task'       { foreach ($req in 'path', 'name') { if (-not $a.PSObject.Properties[$req]) { [void]$errors.Add("$id : action #$i task missing '$req'") } } }
                'appx'       { if (-not $a.PSObject.Properties['name']) { [void]$errors.Add("$id : action #$i appx missing 'name'") } }
                'feature'    { if (-not $a.PSObject.Properties['name']) { [void]$errors.Add("$id : action #$i feature missing 'name'") } }
                'capability' { if (-not $a.PSObject.Properties['name']) { [void]$errors.Add("$id : action #$i capability missing 'name'") } }
                'command'    { if (-not $a.PSObject.Properties['apply']) { [void]$errors.Add("$id : action #$i command missing 'apply'") } }
                'powershell' { if (-not $a.PSObject.Properties['apply']) { [void]$errors.Add("$id : action #$i powershell missing 'apply'") } }
            }
        }
    }
    return $errors.ToArray()
}

$script:ValidDetect = $script:ValidActions + @('registryMatch', 'registryGreater', 'fileContains', 'fileMissing', 'commandMatch')
function Test-ForgeDetectBlocks {
    [CmdletBinding()] param([object[]]$Catalog = (Import-ForgeCatalog))
    $errors = New-Object System.Collections.ArrayList
    foreach ($t in $Catalog) {
        if (-not $t.PSObject.Properties['detect']) { continue }
        $i = 0
        foreach ($d in @($t.detect)) {
            $i++
            if ($d.type -notin $script:ValidDetect) { [void]$errors.Add("$($t.id) : detect #$i unknown type '$($d.type)'"); continue }
            if ($d.type -in 'command', 'powershell') { [void]$errors.Add("$($t.id) : detect #$i type '$($d.type)' is not detectable, use commandMatch") }
            if ($d.type -in 'registryMatch', 'fileContains', 'commandMatch' -and -not $d.PSObject.Properties['pattern']) { [void]$errors.Add("$($t.id) : detect #$i missing 'pattern'") }
            if ($d.type -in 'fileContains', 'fileMissing' -and -not $d.PSObject.Properties['path']) { [void]$errors.Add("$($t.id) : detect #$i missing 'path'") }
            if ($d.type -eq 'commandMatch' -and -not $d.PSObject.Properties['command']) { [void]$errors.Add("$($t.id) : detect #$i missing 'command'") }
        }
    }
    return $errors.ToArray()
}

function Get-ForgeCategories { return $script:Categories }

function Get-ForgeTweak {
    [CmdletBinding()] param([string]$Id = '', [string]$Category = '', [string]$Search = '', [string[]]$Tags = @(), [string]$Risk = '')
    $all = Import-ForgeCatalog
    $r = $all
    if ($Id)       { $r = $r | Where-Object { $_.id -like $Id } }
    if ($Category) { $r = $r | Where-Object { $_.category -eq $Category } }
    if ($Risk)     { $r = $r | Where-Object { $_.risk -eq $Risk } }
    if ($Tags.Count) { $r = $r | Where-Object { $t = $_; ($Tags | Where-Object { $t.PSObject.Properties['tags'] -and $t.tags -contains $_ }).Count -gt 0 } }
    if ($Search) {
        $s = $Search.ToLowerInvariant()
        $r = $r | Where-Object { $_.id -like "*$s*" -or (Get-LocalizedText $_.name).ToLowerInvariant().Contains($s) -or (Get-LocalizedText $_.description).ToLowerInvariant().Contains($s) }
    }
    return @($r)
}

# ------------------------------------------------------------------ applicability
function Test-ForgeTweakApplicable {
    <# Checks minBuild / maxBuild / editions against the running OS. Returns $true/$false + reason via -Reason. #>
    [CmdletBinding()] param([Parameter(Mandatory)]$Tweak, $Os = (Get-ForgeOsInfo), [ref]$Reason)
    $why = ''
    if ($Tweak.PSObject.Properties['minBuild'] -and $Tweak.minBuild -and $Os.Build -and $Os.Build -lt $Tweak.minBuild) { $why = "requires build $($Tweak.minBuild)+" }
    if ($Tweak.PSObject.Properties['maxBuild'] -and $Tweak.maxBuild -and $Os.Build -and $Os.Build -gt $Tweak.maxBuild) { $why = "only up to build $($Tweak.maxBuild)" }
    if ($Tweak.PSObject.Properties['editions'] -and @($Tweak.editions).Count -gt 0 -and $Os.Edition -ne 'N/A') {
        $ok = $false
        foreach ($e in $Tweak.editions) { if ($Os.Edition -like "*$e*") { $ok = $true } }
        if (-not $ok) { $why = "only for editions: $($Tweak.editions -join ', ')" }
    }
    if ($Reason) { $Reason.Value = $why }
    return ($why -eq '')
}

# ------------------------------------------------------------------ state detection
function Get-ForgeTweakState {
    <#
    .SYNOPSIS Determine whether a tweak is currently applied. Returns Applied | NotApplied | Partial | Unknown
    #>
    [CmdletBinding()] param([Parameter(Mandatory)]$Tweak)
    if ($env:OS -ne 'Windows_NT') { return 'Unknown' }
    $checks = if ($Tweak.PSObject.Properties['detect'] -and $Tweak.detect) { @($Tweak.detect) } else { @($Tweak.actions) }
    $total = 0; $hit = 0
    foreach ($a in $checks) {
        switch ($a.type) {
            'registry' {
                $total++
                $cur = Get-RegistryValueSafe -Path $a.path -Name $a.name
                if ($cur -and ("$($cur.Value)" -eq "$($a.value)")) { $hit++ }
            }
            'registryDelete' { $total++; if (-not (Get-RegistryValueSafe -Path $a.path -Name $a.name)) { $hit++ } }
            'registryDeleteKey' { $total++; if (-not (Test-Path -LiteralPath (Resolve-RegistryPath $a.path))) { $hit++ } }
            'service' {
                $total++
                $want = if ($a.PSObject.Properties['startup']) { $a.startup } else { 'Disabled' }
                $wantVal = switch ($want) { 'Automatic' { 2 } 'AutomaticDelayed' { 2 } 'Manual' { 3 } 'Disabled' { 4 } }
                $svc = Get-Service -Name $a.name -ErrorAction SilentlyContinue
                if (-not $svc) { $svc = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "$($a.name)_*" } | Select-Object -First 1 }
                if (-not $svc) { $hit++; continue }   # absent = effectively disabled
                $start = (Get-ItemProperty -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Services\$($svc.Name)" -Name Start -ErrorAction SilentlyContinue).Start
                if ($start -eq $wantVal) { $hit++ }
            }
            'task' {
                $total++
                $p = $a.path; if (-not $p.EndsWith('\')) { $p += '\' }
                $want = if ($a.PSObject.Properties['state']) { $a.state } else { 'Disabled' }
                $task = Get-ScheduledTask -TaskPath $p -TaskName $a.name -ErrorAction SilentlyContinue
                if (-not $task) { $hit++; continue }
                if ($task.State.ToString() -eq $want) { $hit++ }
            }
            'appx' {
                $total++
                if (-not (Get-AppxPackage -AllUsers -Name $a.name -ErrorAction SilentlyContinue)) { $hit++ }
            }
            'feature' {
                $total++
                $want = if ($a.PSObject.Properties['state']) { $a.state } else { 'Disabled' }
                $f = Get-WindowsOptionalFeature -Online -FeatureName $a.name -ErrorAction SilentlyContinue
                if (-not $f -or $f.State.ToString() -like "$want*") { $hit++ }
            }
            'capability' {
                $total++
                $want = if ($a.PSObject.Properties['state']) { $a.state } else { 'Disabled' }
                $c = Get-WindowsCapability -Online -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "$($a.name)*" } | Select-Object -First 1
                if (-not $c) { $hit++; continue }
                if (($want -eq 'Disabled' -and $c.State -eq 'NotPresent') -or ($want -eq 'Enabled' -and $c.State -eq 'Installed')) { $hit++ }
            }
            'registryMatch' {
                $total++
                $cur = Get-RegistryValueSafe -Path $a.path -Name $a.name
                if ($cur -and ("$($cur.Value)" -match $a.pattern)) { $hit++ }
            }
            'registryGreater' {
                $total++
                $cur = Get-RegistryValueSafe -Path $a.path -Name $a.name
                if ($cur -and ([double]$cur.Value -ge [double]$a.value)) { $hit++ }
            }
            'fileContains' {
                $total++
                $p = [Environment]::ExpandEnvironmentVariables($a.path)
                if ((Test-Path -LiteralPath $p) -and ((Get-Content -LiteralPath $p -Raw -ErrorAction SilentlyContinue) -match $a.pattern)) { $hit++ }
            }
            'fileMissing' {
                $total++
                $p = [Environment]::ExpandEnvironmentVariables($a.path)
                if (-not (Test-Path -LiteralPath $p)) { $hit++ }
            }
            'commandMatch' {
                $total++
                try { $out = (& cmd.exe /d /c $a.command 2>&1 | Out-String); if ($out -match $a.pattern) { $hit++ } } catch { }
            }
            default { }   # command / powershell are not detectable unless a 'detect' block is supplied
        }
    }
    if ($total -eq 0) { return 'Unknown' }
    if ($hit -eq $total) { return 'Applied' }
    if ($hit -eq 0) { return 'NotApplied' }
    return 'Partial'
}

# ------------------------------------------------------------------ apply / revert
function Invoke-ForgeAction {
    param([Parameter(Mandatory)][string]$TweakId, [Parameter(Mandatory)]$Action, [bool]$DefaultUser = $false)
    switch ($Action.type) {
        'registry' {
            $kind = if ($Action.PSObject.Properties['kind']) { $Action.kind } else { 'DWord' }
            Set-ForgeRegistry -TweakId $TweakId -Path $Action.path -Name $Action.name -Value $Action.value -Kind $kind
            if ($DefaultUser -and $Action.path -match '^(HKCU:?\\|HKEY_CURRENT_USER\\)' -and (Mount-DefaultUserHive)) {
                $dp = $Action.path -replace '^(HKCU:?\\|HKEY_CURRENT_USER\\)', 'HKU:\WinForgeDefault\'
                Set-ForgeRegistry -TweakId $TweakId -Path $dp -Name $Action.name -Value $Action.value -Kind $kind
            }
        }
        'registryDelete'    { Remove-ForgeRegistryValue -TweakId $TweakId -Path $Action.path -Name $Action.name }
        'registryDeleteKey' { Remove-ForgeRegistryKey -TweakId $TweakId -Path $Action.path }
        'service' {
            $startup = if ($Action.PSObject.Properties['startup']) { $Action.startup } else { 'Disabled' }
            $stop = if ($Action.PSObject.Properties['stop']) { [bool]$Action.stop } else { $true }
            Set-ForgeService -TweakId $TweakId -Name $Action.name -Startup $startup -Stop $stop
        }
        'task' {
            $state = if ($Action.PSObject.Properties['state']) { $Action.state } else { 'Disabled' }
            Set-ForgeScheduledTask -TweakId $TweakId -Path $Action.path -Name $Action.name -State $state
        }
        'appx' {
            $all  = if ($Action.PSObject.Properties['allUsers']) { [bool]$Action.allUsers } else { $true }
            $prov = if ($Action.PSObject.Properties['provisioned']) { [bool]$Action.provisioned } else { $true }
            Remove-ForgeAppx -TweakId $TweakId -Name $Action.name -AllUsers $all -Provisioned $prov | Out-Null
        }
        'feature' {
            $state = if ($Action.PSObject.Properties['state']) { $Action.state } else { 'Disabled' }
            Set-ForgeWindowsFeature -TweakId $TweakId -Name $Action.name -State $state -Kind feature
        }
        'capability' {
            $state = if ($Action.PSObject.Properties['state']) { $Action.state } else { 'Disabled' }
            Set-ForgeWindowsFeature -TweakId $TweakId -Name $Action.name -State $state -Kind capability
        }
        'command'    { $rv = if ($Action.PSObject.Properties['revert']) { $Action.revert } else { '' }; Invoke-ForgeCommand -TweakId $TweakId -Apply $Action.apply -Revert $rv -Shell cmd }
        'powershell' { $rv = if ($Action.PSObject.Properties['revert']) { $Action.revert } else { '' }; Invoke-ForgeCommand -TweakId $TweakId -Apply $Action.apply -Revert $rv -Shell powershell }
    }
}

function Invoke-ForgeTweak {
    <#
    .SYNOPSIS Apply one tweak. Returns a result object { Id, Status, Message, Reboot }.
    #>
    [CmdletBinding()] param([Parameter(Mandatory)]$Tweak, [switch]$DefaultUser)
    $name = Get-LocalizedText $Tweak.name
    $reason = ''
    if (-not (Test-ForgeTweakApplicable -Tweak $Tweak -Reason ([ref]$reason))) {
        Write-ForgeLog "$name — skipped ($reason)" -Level Warn
        return [PSCustomObject]@{ Id = $Tweak.id; Status = 'Skipped'; Message = $reason; Reboot = $false }
    }
    Write-ForgeLog $name -Level Step
    $du = $DefaultUser.IsPresent -or ($Tweak.PSObject.Properties['defaultUser'] -and [bool]$Tweak.defaultUser)
    $failed = 0
    foreach ($a in $Tweak.actions) {
        try { Invoke-ForgeAction -TweakId $Tweak.id -Action $a -DefaultUser $du }
        catch { $failed++; Write-ForgeLog "$($a.type) failed: $($_.Exception.Message.Split("`n")[0])" -Level Warn }
    }
    if ($Tweak.PSObject.Properties['restartExplorer'] -and $Tweak.restartExplorer) { $script:NeedExplorerRestart = $true }
    $status = if ($failed -eq 0) { 'Applied' } elseif ($failed -lt @($Tweak.actions).Count) { 'Partial' } else { 'Failed' }
    $reboot = ($Tweak.PSObject.Properties['reboot'] -and [bool]$Tweak.reboot)
    Write-ForgeLog "$name — $status" -Level $(if ($status -eq 'Applied') { 'Ok' } else { 'Warn' })
    return [PSCustomObject]@{ Id = $Tweak.id; Status = $status; Message = ''; Reboot = $reboot }
}

function Undo-ForgeTweak {
    <#
    .SYNOPSIS Revert one tweak using its explicit 'revert' actions if present, otherwise the newest journal that contains it.
    #>
    [CmdletBinding()] param([Parameter(Mandatory)]$Tweak)
    $name = Get-LocalizedText $Tweak.name
    Write-ForgeLog "Revert: $name" -Level Step
    if ($Tweak.PSObject.Properties['revert'] -and @($Tweak.revert).Count -gt 0) {
        foreach ($a in $Tweak.revert) {
            try { Invoke-ForgeAction -TweakId "$($Tweak.id).revert" -Action $a }
            catch { Write-ForgeLog "revert action failed: $($_.Exception.Message.Split("`n")[0])" -Level Warn }
        }
        return [PSCustomObject]@{ Id = $Tweak.id; Status = 'Reverted'; Source = 'explicit' }
    }
    $journals = Get-ForgeJournalList
    foreach ($j in $journals) {
        $doc = Get-Content -LiteralPath $j.File -Raw -Encoding UTF8 | ConvertFrom-Json
        if (@($doc.tweaks | Where-Object { $_.id -eq $Tweak.id }).Count -gt 0) {
            Restore-ForgeJournal -File $j.File -TweakId $Tweak.id | Out-Null
            return [PSCustomObject]@{ Id = $Tweak.id; Status = 'Reverted'; Source = $j.Id }
        }
    }
    Write-ForgeLog "$name — nothing to revert (no journal and no explicit revert)" -Level Warn
    return [PSCustomObject]@{ Id = $Tweak.id; Status = 'NothingToRevert'; Source = '' }
}

$script:NeedExplorerRestart = $false
function Test-ForgeExplorerRestartNeeded { $v = $script:NeedExplorerRestart; $script:NeedExplorerRestart = $false; return $v }

# ------------------------------------------------------------------ profiles
function Import-ForgeProfiles {
    [CmdletBinding()] param([string]$Path = (Join-Path $script:RootDir 'profiles'), [switch]$Force)
    if ($script:Profiles -and -not $Force) { return $script:Profiles }
    $list = New-Object System.Collections.ArrayList
    foreach ($f in (Get-ChildItem -LiteralPath $Path -Filter '*.json' | Sort-Object Name)) {
        $p = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        $p | Add-Member -NotePropertyName sourceFile -NotePropertyValue $f.Name -Force
        [void]$list.Add($p)
    }
    $script:Profiles = $list.ToArray() | Sort-Object { if ($_.PSObject.Properties['order']) { [int]$_.order } else { 99 } }
    return $script:Profiles
}

function Resolve-ForgeProfile {
    <#
    .SYNOPSIS Expand a profile's include/exclude patterns into concrete tweak objects.
      Patterns: exact id, wildcard (privacy.*), "category:privacy", "risk:safe", "tag:telemetry".
    #>
    [CmdletBinding()] param([Parameter(Mandatory)]$Profile)
    $all = Import-ForgeCatalog
    $hit = @{}
    foreach ($pat in @($Profile.include)) {
        foreach ($t in $all) { if (Test-ForgePattern -Pattern $pat -Tweak $t) { $hit[$t.id] = $true } }
    }
    if ($Profile.PSObject.Properties['exclude']) {
        foreach ($pat in @($Profile.exclude)) {
            foreach ($t in $all) { if ($hit.ContainsKey($t.id) -and (Test-ForgePattern -Pattern $pat -Tweak $t)) { $hit.Remove($t.id) } }
        }
    }
    return @($all | Where-Object { $hit.ContainsKey($_.id) })
}

function Test-ForgePattern {
    param([Parameter(Mandatory)][string]$Pattern, [Parameter(Mandatory)]$Tweak)
    if ($Pattern -like 'category:*') { return ($Tweak.category -eq $Pattern.Substring(9)) }
    if ($Pattern -like 'risk:*')     { return ($Tweak.risk -eq $Pattern.Substring(5)) }
    if ($Pattern -like 'tag:*')      { return [bool]($Tweak.PSObject.Properties['tags'] -and ($Tweak.tags -contains $Pattern.Substring(4))) }
    return ($Tweak.id -like $Pattern)
}

function Test-ForgeProfiles {
    [CmdletBinding()] param()
    $errors = New-Object System.Collections.ArrayList
    $all = Import-ForgeCatalog
    foreach ($p in (Import-ForgeProfiles)) {
        if (-not $p.id) { [void]$errors.Add("profile without id: $($p.sourceFile)"); continue }
        if (-not (Get-LocalizedText $p.name)) { [void]$errors.Add("$($p.id): missing name") }
        if (-not $p.PSObject.Properties['include']) { [void]$errors.Add("$($p.id): missing include"); continue }
        foreach ($pat in @($p.include) + @(if ($p.PSObject.Properties['exclude']) { $p.exclude })) {
            if ($pat -match '^(category|risk|tag):') { continue }
            if (@($all | Where-Object { $_.id -like $pat }).Count -eq 0) { [void]$errors.Add("$($p.id): pattern '$pat' matches no tweak") }
        }
        if (@(Resolve-ForgeProfile -Profile $p).Count -eq 0) { [void]$errors.Add("$($p.id): resolves to zero tweaks") }
    }
    return $errors.ToArray()
}

# ------------------------------------------------------------------ export / import selection
function Export-ForgeSelection {
    param([Parameter(Mandatory)][string[]]$Ids, [Parameter(Mandatory)][string]$Path, [string]$Name = 'custom')
    [PSCustomObject]@{ id = $Name; name = @{ en = $Name }; description = @{ en = "Exported $(Get-Date -Format 'yyyy-MM-dd HH:mm')" }; version = 1; include = $Ids } |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Path -Encoding UTF8
}

Export-ModuleMember -Function *-Forge*, Get-LocalizedText
