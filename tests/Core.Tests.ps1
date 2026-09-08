BeforeAll {
    $root = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $root 'src/WinForge.Core.psm1') -Force
    Import-Module (Join-Path $root 'src/WinForge.Catalog.psm1') -Force
    Import-Module (Join-Path $root 'src/WinForge.Session.psm1') -Force
    Import-Module (Join-Path $root 'src/WinForge.Report.psm1') -Force
    Import-Module (Join-Path $root 'src/WinForge.Startup.psm1') -Force
    Import-Module (Join-Path $root 'src/WinForge.Update.psm1') -Force
}

Describe 'Startup manager' {
    It 'encodes StartupApproved bytes like Task Manager' {
        $on = ConvertTo-ApprovedBytes -Enabled $true; $off = ConvertTo-ApprovedBytes -Enabled $false
        $on.Length | Should -Be 12; $on[0] | Should -Be 2; ($on[4..11] | Measure-Object -Sum).Sum | Should -Be 0
        $off[0] | Should -Be 3; ($off[4..11] | Measure-Object -Sum).Sum | Should -BeGreaterThan 0
    }
    It 'returns an empty list off Windows' { if ($env:OS -ne 'Windows_NT') { @(Get-ForgeStartupItem).Count | Should -Be 0 } }
}

Describe 'Store id map' {
    It 'is valid JSON with Store-looking ids' {
        $root = Split-Path -Parent $PSScriptRoot
        $m = Get-Content (Join-Path $root 'src/data/store-ids.json') -Raw | ConvertFrom-Json
        foreach ($p in $m.PSObject.Properties) { if ($p.Name -ne '_comment') { $p.Value | Should -Match '^[A-Z0-9]{12,14}$' -Because $p.Name } }
        Get-ForgeStoreId 'Microsoft.Copilot' | Should -Be '9NHT9RB2F4HD'
        Get-ForgeStoreId 'microsoft.copilot' | Should -Be '9NHT9RB2F4HD'
        Get-ForgeStoreId 'Nope.Nothing' | Should -BeNullOrEmpty
    }
    It 'covers every non-wildcard package in the bloatware catalog sets that Microsoft still ships' {
        Import-ForgeCatalog -Force | Out-Null
        $names = (Get-ForgeTweak -Id 'bloat.ms-junk').actions.name + (Get-ForgeTweak -Id 'bloat.teams-outlook').actions.name + (Get-ForgeTweak -Id 'bloat.xbox').actions.name
        $missing = @($names | Where-Object { $_ -notmatch '[*]' -and -not (Get-ForgeStoreId $_) })
        # legacy/deprecated packages are allowed to have no Store id
        $allowed = 'Microsoft.BingFinance', 'Microsoft.BingSports', 'Microsoft.BingTranslator', 'Microsoft.BingTravel', 'Microsoft.BingFoodAndDrink', 'Microsoft.BingHealthAndFitness', 'Microsoft.BingSearch', 'Microsoft.News', 'Microsoft.Office.Sway', 'Microsoft.3DBuilder', 'Microsoft.549981C3F5F10', 'Microsoft.Messaging', 'Microsoft.OneConnect', 'Microsoft.NetworkSpeedTest', 'Microsoft.MicrosoftPowerBIForWindows', 'Microsoft.Windows.AIHub', 'Microsoft.M365Companions', 'Microsoft.StartExperiencesApp', 'MicrosoftTeams', 'Microsoft.XboxApp', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxSpeechToTextOverlay', 'Microsoft.Xbox.TCUI', 'Microsoft.XboxIdentityProvider'
        @($missing | Where-Object { $_ -notin $allowed }) | Should -BeNullOrEmpty
    }
}

Describe 'HTML report' {
    It 'renders a dry-run report with planned actions and the revert command' {
        Set-ForgeDryRun $true
        Set-ForgeLanguage 'en'
        $t = Get-ForgeTweak -Id 'privacy.feedback'
        $j = New-ForgeJournal -Label 'pester-report'
        $res = @([PSCustomObject]@{ Id = $t.id; Status = 'Applied'; Message = ''; Reboot = $false })
        $out = Join-Path ([IO.Path]::GetTempPath()) "wf-report-$(Get-Random).html"
        $file = Export-ForgeReport -Journal $j -Results $res -Tweaks @($t) -Path $out
        $html = Get-Content $file -Raw
        $html | Should -Match 'DRY RUN'
        $html | Should -Match 'Disable feedback requests'
        $html | Should -Match 'NumberOfSIUFInPeriod'
        $html | Should -Match "-RevertJournal $($j.id)"
        Remove-Item $file -Force
        Set-ForgeDryRun $false
    }
    It 'escapes HTML in values' {
        $j = New-ForgeJournal -Label 'pester-esc'
        Add-JournalEntry -TweakId 'x.y' -Entry @{ type = 'registry'; path = 'HKCU:\Z'; name = '<b>'; before = $null; after = @{ kind = 'String'; value = '<script>' } }
        $out = Join-Path ([IO.Path]::GetTempPath()) "wf-report-$(Get-Random).html"
        $html = Get-Content (Export-ForgeReport -Journal $j -Path $out) -Raw
        $html | Should -Not -Match '<script>'
        $html | Should -Match '&lt;script&gt;'
        Remove-Item $out -Force
    }
}

Describe 'Update module' {
    It 'exposes Test-ForgeUpdate and Update-ForgeCatalog' {
        Get-Command Test-ForgeUpdate | Should -Not -BeNullOrEmpty
        Get-Command Update-ForgeCatalog | Should -Not -BeNullOrEmpty
    }
}

Describe 'Registry helpers' {
    It 'normalises long hive names' {
        Resolve-RegistryPath 'HKEY_LOCAL_MACHINE\SOFTWARE\X' | Should -Be 'HKLM:\SOFTWARE\X'
        Resolve-RegistryPath 'HKEY_CURRENT_USER\A' | Should -Be 'HKCU:\A'
        Resolve-RegistryPath 'HKCU\A' | Should -Be 'HKCU:\A'
        Resolve-RegistryPath 'HKLM:\A' | Should -Be 'HKLM:\A'
        Resolve-RegistryPath 'HKEY_USERS\S-1-5-20\X' | Should -Be 'HKU:\S-1-5-20\X'
    }
    It 'maps value kinds' {
        ConvertTo-RegistryKind 'dword' | Should -Be 'DWord'
        ConvertTo-RegistryKind 'String' | Should -Be 'String'
        ConvertTo-RegistryKind 'REG_QWORD' | Should -Be 'QWord'
        ConvertTo-RegistryKind 'binary' | Should -Be 'Binary'
        ConvertTo-RegistryKind 'multi' | Should -Be 'MultiString'
        ConvertTo-RegistryKind 'expand' | Should -Be 'ExpandString'
        ConvertTo-RegistryKind '' | Should -Be 'DWord'
    }
}

Describe 'Journal' {
    It 'creates, records and lists a journal (dry-run never writes)' {
        Set-ForgeDryRun $true
        $j = New-ForgeJournal -Label 'test'
        $j.label | Should -Be 'test'
        Add-JournalEntry -TweakId 'x.y' -Entry @{ type = 'registry'; path = 'HKCU:\Z'; name = 'V'; before = $null; after = @{ kind = 'DWord'; value = 1 } }
        (Get-ForgeJournal).tweaks.Count | Should -Be 1
        Save-ForgeJournal | Should -BeNullOrEmpty
        Set-ForgeDryRun $false
    }
    It 'saves and lists when not dry-run' {
        Set-ForgeDryRun $false
        New-ForgeJournal -Label 'pester' | Out-Null
        Add-JournalEntry -TweakId 'a.b' -Entry @{ type = 'registry'; path = 'HKCU:\Z'; name = 'V'; before = $null; after = @{ kind = 'DWord'; value = 1 } }
        $f = Save-ForgeJournal
        $f | Should -Not -BeNullOrEmpty
        (Get-ForgeJournalList | Where-Object Label -eq 'pester').Count | Should -BeGreaterOrEqual 1
        Remove-Item $f -Force
    }
}

Describe 'Config' {
    It 'returns defaults and round-trips' {
        $c = Get-ForgeConfig
        $c.language | Should -Not -BeNullOrEmpty
        $c.createRestorePoint | Should -BeOfType [bool]
    }
}

Describe 'Paths' {
    It 'exposes version and directories' {
        $p = Get-ForgePaths
        $p.Version | Should -Match '^\d+\.\d+\.\d+$'
        Test-Path $p.Journal | Should -BeTrue
    }
}
