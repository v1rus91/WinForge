#Requires -Version 5.1
<#
    WinForge.Update — release check (GitHub Releases) and catalog-only updates
    (tweaks are JSON, so they can be refreshed without a new program version).
#>
Set-StrictMode -Version 2.0
$script:Repo = 'v1rus91/WinForge'

function Test-ForgeUpdate {
    <# Returns { Current, Latest, Available, Url } or $null when offline. Cached in config for 24 h unless -Force. #>
    [CmdletBinding()] param([switch]$Force)
    $cfg = Get-ForgeConfig
    $current = (Get-ForgePaths).Version
    if (-not $Force -and $cfg.PSObject.Properties['lastUpdateCheck'] -and $cfg.lastUpdateCheck -and $cfg.PSObject.Properties['latestVersion'] -and $cfg.latestVersion) {
        try { if (((Get-Date) - [datetime]$cfg.lastUpdateCheck).TotalHours -lt 24) { return [PSCustomObject]@{ Current = $current; Latest = $cfg.latestVersion; Available = ([version]$cfg.latestVersion -gt [version]$current); Url = "https://github.com/$script:Repo/releases/latest"; Cached = $true } } } catch { }
    }
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $rel = Invoke-RestMethod "https://api.github.com/repos/$script:Repo/releases/latest" -Headers @{ 'User-Agent' = "WinForge/$current" } -TimeoutSec 8
        $latest = ($rel.tag_name -replace '^v', '')
        $cfg | Add-Member -NotePropertyName lastUpdateCheck -NotePropertyValue (Get-Date -Format o) -Force
        $cfg | Add-Member -NotePropertyName latestVersion -NotePropertyValue $latest -Force
        Save-ForgeConfig $cfg
        return [PSCustomObject]@{ Current = $current; Latest = $latest; Available = ([version]$latest -gt [version]$current); Url = $rel.html_url; Cached = $false }
    } catch { Write-ForgeLog "update check failed: $($_.Exception.Message)" -Level Debug; return $null }
}

function Update-ForgeCatalog {
    <#
    .SYNOPSIS Download the latest catalog/ and profiles/ from the main branch, validate, and replace the local copies (old ones backed up).
    #>
    [CmdletBinding()] param([string]$Branch = 'main')
    $root = (Get-ForgePaths).Root
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "winforge-catalog-$(Get-Random)"
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $zip = Join-Path $tmp 'src.zip'
        Invoke-WebRequest "https://github.com/$script:Repo/archive/refs/heads/$Branch.zip" -OutFile $zip -UseBasicParsing -TimeoutSec 30
        Expand-Archive $zip $tmp -Force
        $inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
        $newCat = Join-Path $inner.FullName 'catalog'; $newProf = Join-Path $inner.FullName 'profiles'
        $errs = @(Test-ForgeCatalog -Catalog (Import-ForgeCatalog -Path $newCat -Force))
        if ($errs.Count) { Import-ForgeCatalog -Force | Out-Null; throw "downloaded catalog is invalid: $($errs[0])" }
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $bak = Join-Path (Get-ForgePaths).Backup "catalog-$stamp"
        New-Item -ItemType Directory -Path $bak -Force | Out-Null
        Copy-Item (Join-Path $root 'catalog') $bak -Recurse -Force; Copy-Item (Join-Path $root 'profiles') $bak -Recurse -Force
        Copy-Item (Join-Path $newCat '*.json') (Join-Path $root 'catalog') -Force
        Copy-Item (Join-Path $newProf '*.json') (Join-Path $root 'profiles') -Force
        $n = (Import-ForgeCatalog -Force).Count; Import-ForgeProfiles -Force | Out-Null
        Write-ForgeLog "catalog updated from ${Branch}: $n tweaks (backup in $bak)" -Level Ok
        return $n
    } finally { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

Export-ModuleMember -Function Test-ForgeUpdate, Update-ForgeCatalog
