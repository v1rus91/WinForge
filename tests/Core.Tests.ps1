BeforeAll {
    $root = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $root 'src/WinForge.Core.psm1') -Force
    Import-Module (Join-Path $root 'src/WinForge.Catalog.psm1') -Force
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
