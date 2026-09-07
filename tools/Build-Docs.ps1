<# Generates docs/TWEAKS.md from the catalog. Run: pwsh tools/Build-Docs.ps1 #>
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'src/WinForge.Core.psm1') -Force
Import-Module (Join-Path $root 'src/WinForge.Catalog.psm1') -Force
Set-ForgeLanguage en
$cat = Import-ForgeCatalog -Force
$cats = Get-ForgeCategories
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# WinForge tweak catalog')
[void]$sb.AppendLine('')
[void]$sb.AppendLine("_Generated $(Get-Date -Format 'yyyy-MM-dd') from `catalog/*.json` — $($cat.Count) tweaks. Do not edit by hand._")
[void]$sb.AppendLine('')
[void]$sb.AppendLine('Legend: **safe** = no functionality loss · **moderate** = read the description · **advanced** = opt-in, never part of a profile, never counted in the score. `⟳` needs reboot · `✖` not reversible (package removal) · `build N+` minimum Windows build.')
[void]$sb.AppendLine('')
foreach ($g in ($cat | Group-Object category | Sort-Object { $cats[$_.Name].order })) {
    [void]$sb.AppendLine("## $($cats[$g.Name].icon) $($g.Name) ($($g.Count))")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| id | tweak | risk | notes | what it touches |')
    [void]$sb.AppendLine('|---|---|---|---|---|')
    foreach ($t in $g.Group) {
        $notes = @()
        if ($t.PSObject.Properties['reboot'] -and $t.reboot) { $notes += '⟳' }
        if ($t.PSObject.Properties['reversible'] -and $t.reversible -eq $false) { $notes += '✖' }
        if ($t.PSObject.Properties['minBuild'] -and $t.minBuild) { $notes += "build $($t.minBuild)+" }
        if ($t.PSObject.Properties['editions'] -and $t.editions) { $notes += ($t.editions -join '/') }
        if ($t.PSObject.Properties['tags'] -and $t.tags -contains 'recommended') { $notes += '★' }
        $touch = @($t.actions | Group-Object type | ForEach-Object { "$($_.Count)× $($_.Name)" }) -join ', '
        $name = (Get-LocalizedText $t.name) -replace '\|', '\|'
        $desc = (Get-LocalizedText $t.description) -replace '\|', '\|'
        [void]$sb.AppendLine("| ``$($t.id)`` | **$name**<br><sub>$desc</sub> | $($t.risk) | $($notes -join ' ') | $touch |")
    }
    [void]$sb.AppendLine('')
}
[void]$sb.AppendLine('## Profiles')
[void]$sb.AppendLine('')
foreach ($p in Import-ForgeProfiles -Force) {
    $sel = Resolve-ForgeProfile $p
    [void]$sb.AppendLine("### $($p.icon) $(Get-LocalizedText $p.name) (``$($p.id)``, $($sel.Count) tweaks)")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine((Get-LocalizedText $p.description))
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine(($sel | ForEach-Object { "``$($_.id)``" }) -join ' · ')
    [void]$sb.AppendLine('')
}
$out = Join-Path $root 'docs/TWEAKS.md'
[IO.File]::WriteAllText($out, $sb.ToString(), [Text.UTF8Encoding]::new($false))
Write-Host "wrote $out ($($cat.Count) tweaks)"
