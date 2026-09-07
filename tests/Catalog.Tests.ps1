# Cross-platform tests: schema, ids, profiles, i18n, applicability gating.
BeforeAll {
    $root = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $root 'src/WinForge.Core.psm1') -Force
    Import-Module (Join-Path $root 'src/WinForge.Catalog.psm1') -Force
    Import-Module (Join-Path $root 'src/WinForge.Diagnostics.psm1') -Force
    Import-Module (Join-Path $root 'src/WinForge.Session.psm1') -Force
    $script:Catalog = Import-ForgeCatalog -Force
    $script:Profiles = Import-ForgeProfiles -Force
}

Describe 'Catalog schema' {
    It 'loads a substantial catalog' { $script:Catalog.Count | Should -BeGreaterThan 100 }
    It 'passes Test-ForgeCatalog' { Test-ForgeCatalog -Catalog $script:Catalog | Should -BeNullOrEmpty }
    It 'passes Test-ForgeDetectBlocks' { Test-ForgeDetectBlocks -Catalog $script:Catalog | Should -BeNullOrEmpty }
    It 'has unique ids' { ($script:Catalog.id | Group-Object | Where-Object Count -gt 1) | Should -BeNullOrEmpty }
    It 'every tweak has en and uk name + description' {
        foreach ($t in $script:Catalog) {
            $t.name.en | Should -Not -BeNullOrEmpty -Because "$($t.id) name.en"
            $t.name.uk | Should -Not -BeNullOrEmpty -Because "$($t.id) name.uk"
            $t.description.en | Should -Not -BeNullOrEmpty -Because "$($t.id) description.en"
            $t.description.uk | Should -Not -BeNullOrEmpty -Because "$($t.id) description.uk"
        }
    }
    It 'id prefix matches its category file' {
        $map = @{ privacy = 'privacy'; ai = 'ai'; bloatware = 'bloat'; performance = 'perf'; gaming = 'gaming'; services = 'svc'; ui = 'ui'; explorer = 'explorer'; edge = 'edge'; updates = 'updates'; network = 'net'; security = 'sec'; power = 'power'; advanced = 'adv' }
        foreach ($t in $script:Catalog) { $t.id.Split('.')[0] | Should -Be $map[$t.category] -Because $t.id }
    }
    It 'registry actions use provider-style paths with a hive prefix' {
        foreach ($t in $script:Catalog) { foreach ($a in $t.actions) { if ($a.type -eq 'registry') { $a.path | Should -Match '^(HKLM|HKCU|HKCR|HKU):\\' -Because "$($t.id)" } } }
    }
    It 'irreversible tweaks are flagged reversible=false and are appx/command based' {
        foreach ($t in $script:Catalog) {
            $hasAppx = @($t.actions | Where-Object type -eq 'appx').Count -gt 0
            if ($hasAppx -and $t.category -eq 'bloatware') { ($t.PSObject.Properties['reversible'] -and $t.reversible -eq $false) | Should -BeTrue -Because "$($t.id) removes packages" }
        }
    }
    It 'advanced tweaks have weight 0 (never counted in score)' {
        foreach ($t in ($script:Catalog | Where-Object risk -eq 'advanced')) { [int]$(if ($t.PSObject.Properties['weight']) { $t.weight } else { 1 }) | Should -Be 0 -Because $t.id }
    }
    It 'every powershell/command action that is not reversible=false has a revert or a journalable sibling' {
        foreach ($t in $script:Catalog) {
            if ($t.PSObject.Properties['reversible'] -and $t.reversible -eq $false) { continue }
            foreach ($a in $t.actions) {
                if ($a.type -in 'command', 'powershell') {
                    $hasRevert = $a.PSObject.Properties['revert'] -and $a.revert
                    $hasJournalable = @($t.actions | Where-Object type -in 'registry', 'service', 'task', 'feature', 'capability').Count -gt 0
                    ($hasRevert -or $hasJournalable) | Should -BeTrue -Because "$($t.id) $($a.type) action needs revert"
                }
            }
        }
    }
    It 'build gates are sane (22000..27000)' {
        foreach ($t in $script:Catalog) { if ($t.PSObject.Properties['minBuild'] -and $t.minBuild) { $t.minBuild | Should -BeGreaterOrEqual 22000; $t.minBuild | Should -BeLessThan 27000 } }
    }
}

Describe 'Profiles' {
    It 'passes Test-ForgeProfiles' { Test-ForgeProfiles | Should -BeNullOrEmpty }
    It 'has the seven built-in profiles' { $script:Profiles.id | Sort-Object | Should -Be @('balanced', 'developer', 'gaming', 'gaming-desktop', 'laptop', 'minimal', 'privacy') }
    It 'balanced contains no advanced tweaks' { (Resolve-ForgeProfile ($script:Profiles | Where-Object id -eq 'balanced') | Where-Object risk -eq 'advanced') | Should -BeNullOrEmpty }
    It 'laptop never enables Ultimate plan or power throttling off' {
        $ids = (Resolve-ForgeProfile ($script:Profiles | Where-Object id -eq 'laptop')).id
        $ids | Should -Not -Contain 'power.ultimate-plan'; $ids | Should -Not -Contain 'perf.power-throttling-off'
    }
    It 'gaming-desktop has no advanced tweaks and no laptop-only bits' {
        $sel = Resolve-ForgeProfile ($script:Profiles | Where-Object id -eq 'gaming-desktop')
        ($sel | Where-Object risk -eq 'advanced') | Should -BeNullOrEmpty
        $sel.id | Should -Contain 'power.desktop-max'; $sel.id | Should -Not -Contain 'power.modern-standby-network-off'
    }
    It 'gaming keeps Xbox apps' { (Resolve-ForgeProfile ($script:Profiles | Where-Object id -eq 'gaming')).id | Should -Not -Contain 'bloat.xbox' }
    It 'pattern matcher supports category/risk/tag/wildcard' {
        $t = $script:Catalog | Where-Object id -eq 'privacy.telemetry'
        Test-ForgePattern -Pattern 'category:privacy' -Tweak $t | Should -BeTrue
        Test-ForgePattern -Pattern 'risk:safe' -Tweak $t | Should -BeTrue
        Test-ForgePattern -Pattern 'tag:telemetry' -Tweak $t | Should -BeTrue
        Test-ForgePattern -Pattern 'privacy.*' -Tweak $t | Should -BeTrue
        Test-ForgePattern -Pattern 'ai.*' -Tweak $t | Should -BeFalse
    }
    It 'Get-ForgeSelectionFromIds preserves catalog order and dedupes' {
        $sel = Get-ForgeSelectionFromIds -Ids @('ai.recall', 'privacy.telemetry', 'ai.*', 'privacy.telemetry')
        $sel[0].id | Should -Be 'privacy.telemetry'
        ($sel.id | Group-Object | Where-Object Count -gt 1) | Should -BeNullOrEmpty
    }
}

Describe 'i18n' {
    It 'uk.json has every key en.json has' {
        $root = Split-Path -Parent $PSScriptRoot
        $en = (Get-Content (Join-Path $root 'src/i18n/en.json') -Raw | ConvertFrom-Json).PSObject.Properties.Name
        $uk = (Get-Content (Join-Path $root 'src/i18n/uk.json') -Raw | ConvertFrom-Json).PSObject.Properties.Name
        Compare-Object $en $uk | Should -BeNullOrEmpty
    }
    It 'falls back to en for unknown language' { Set-ForgeLanguage 'xx'; Get-ForgeString 'menu.exit' | Should -Be 'Exit' }
    It 'formats placeholders' { Set-ForgeLanguage 'en'; Get-ForgeString 'msg.done' @(1, 2, 3) | Should -Be 'Done: 1 applied, 2 skipped, 3 failed' }
    It 'Get-LocalizedText honours language and falls back' {
        Set-ForgeLanguage 'uk'; Get-LocalizedText ([PSCustomObject]@{ en = 'A'; uk = 'Б' }) | Should -Be 'Б'
        Get-LocalizedText ([PSCustomObject]@{ en = 'A' }) | Should -Be 'A'
        Get-LocalizedText 'plain' | Should -Be 'plain'
    }
}

Describe 'Applicability gating' {
    It 'skips 25H2-only tweaks on 23H2' {
        $t = $script:Catalog | Where-Object id -eq 'ui.drag-tray-off'
        $os = [PSCustomObject]@{ Build = 22631; Edition = 'Professional' }
        $r = ''; Test-ForgeTweakApplicable -Tweak $t -Os $os -Reason ([ref]$r) | Should -BeFalse; $r | Should -Match '26200'
    }
    It 'allows it on 25H2' {
        $t = $script:Catalog | Where-Object id -eq 'ui.drag-tray-off'
        Test-ForgeTweakApplicable -Tweak $t -Os ([PSCustomObject]@{ Build = 26200; Edition = 'Core' }) | Should -BeTrue
    }
    It 'edition gate blocks Sandbox on Home' {
        $t = $script:Catalog | Where-Object id -eq 'adv.windows-sandbox'
        Test-ForgeTweakApplicable -Tweak $t -Os ([PSCustomObject]@{ Build = 26100; Edition = 'Core' }) | Should -BeFalse
        Test-ForgeTweakApplicable -Tweak $t -Os ([PSCustomObject]@{ Build = 26100; Edition = 'Professional' }) | Should -BeTrue
    }
}

Describe 'Score' {
    It 'is 0 when nothing applied and 100 when everything applied' {
        $cache = @{}; foreach ($t in $script:Catalog) { $cache[$t.id] = 'NotApplied' }
        (Get-ForgeScore -Catalog $script:Catalog -StateCache $cache).Overall | Should -Be 0
        foreach ($k in @($cache.Keys)) { $cache[$k] = 'Applied' }
        (Get-ForgeScore -Catalog $script:Catalog -StateCache $cache).Overall | Should -Be 100
    }
    It 'ignores advanced tweaks entirely' {
        $cache = @{}; foreach ($t in $script:Catalog) { $cache[$t.id] = if ($t.risk -eq 'advanced') { 'NotApplied' } else { 'Applied' } }
        (Get-ForgeScore -Catalog $script:Catalog -StateCache $cache).Overall | Should -Be 100
    }
}
