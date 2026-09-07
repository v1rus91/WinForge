<#
    WinForge GUI — WPF, dark, single window. Dot-sourced by WinForge.ps1 (modules already loaded, elevated).
    Long operations (state scan, apply, revert, app removal, cleanup) run in a background runspace and
    stream log lines through a synchronized hashtable polled by a DispatcherTimer, so the window never freezes.
#>
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml

$script:Xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="WinForge" Width="1240" Height="800" MinWidth="980" MinHeight="620"
        WindowStartupLocation="CenterScreen" Background="#0F1117" FontFamily="Segoe UI Variable, Segoe UI" FontSize="13" Foreground="#E6E8EF"
        UseLayoutRounding="True" SnapsToDevicePixels="True">
  <Window.Resources>
    <SolidColorBrush x:Key="Bg" Color="#0F1117"/>
    <SolidColorBrush x:Key="Panel" Color="#171A23"/>
    <SolidColorBrush x:Key="Card" Color="#1C2030"/>
    <SolidColorBrush x:Key="CardHover" Color="#232840"/>
    <SolidColorBrush x:Key="Border" Color="#2A2F45"/>
    <SolidColorBrush x:Key="Accent" Color="#4F8CFF"/>
    <SolidColorBrush x:Key="Accent2" Color="#22D3EE"/>
    <SolidColorBrush x:Key="Muted" Color="#8B93A7"/>
    <SolidColorBrush x:Key="Text" Color="#E6E8EF"/>
    <SolidColorBrush x:Key="Green" Color="#34D399"/>
    <SolidColorBrush x:Key="Yellow" Color="#FBBF24"/>
    <SolidColorBrush x:Key="Red" Color="#F87171"/>
    <Style TargetType="TextBlock"><Setter Property="Foreground" Value="{StaticResource Text}"/><Setter Property="TextWrapping" Value="Wrap"/></Style>
    <Style TargetType="Button">
      <Setter Property="Background" Value="{StaticResource Card}"/>
      <Setter Property="Foreground" Value="{StaticResource Text}"/>
      <Setter Property="BorderBrush" Value="{StaticResource Border}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="14,7"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="{StaticResource CardHover}"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.45"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="Primary" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
      <Setter Property="Background" Value="{StaticResource Accent}"/>
      <Setter Property="BorderBrush" Value="{StaticResource Accent}"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>
    <Style x:Key="Danger" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
      <Setter Property="BorderBrush" Value="{StaticResource Red}"/>
      <Setter Property="Foreground" Value="{StaticResource Red}"/>
    </Style>
    <Style TargetType="CheckBox"><Setter Property="Foreground" Value="{StaticResource Text}"/><Setter Property="VerticalAlignment" Value="Center"/><Setter Property="Cursor" Value="Hand"/></Style>
    <Style TargetType="TextBox">
      <Setter Property="Background" Value="{StaticResource Card}"/><Setter Property="Foreground" Value="{StaticResource Text}"/>
      <Setter Property="BorderBrush" Value="{StaticResource Border}"/><Setter Property="Padding" Value="10,7"/><Setter Property="CaretBrush" Value="{StaticResource Text}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TextBox">
            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="8" Padding="{TemplateBinding Padding}">
              <ScrollViewer x:Name="PART_ContentHost"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="ComboBox"><Setter Property="Background" Value="{StaticResource Card}"/><Setter Property="Foreground" Value="#111"/></Style>
    <Style TargetType="ListView"><Setter Property="Background" Value="{StaticResource Panel}"/><Setter Property="Foreground" Value="{StaticResource Text}"/><Setter Property="BorderBrush" Value="{StaticResource Border}"/></Style>
    <Style TargetType="ListViewItem"><Setter Property="Foreground" Value="{StaticResource Text}"/><Setter Property="Padding" Value="4"/>
      <Style.Triggers><Trigger Property="IsSelected" Value="True"><Setter Property="Background" Value="{StaticResource CardHover}"/></Trigger></Style.Triggers></Style>
    <Style TargetType="GridViewColumnHeader"><Setter Property="Background" Value="{StaticResource Card}"/><Setter Property="Foreground" Value="{StaticResource Muted}"/><Setter Property="BorderBrush" Value="{StaticResource Border}"/><Setter Property="Padding" Value="6,4"/></Style>
    <Style TargetType="ProgressBar">
      <Setter Property="Height" Value="8"/><Setter Property="Background" Value="#2A2F45"/><Setter Property="Foreground" Value="{StaticResource Accent}"/><Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ProgressBar">
            <Border Background="{TemplateBinding Background}" CornerRadius="4">
              <Grid><Border x:Name="PART_Track"/><Border x:Name="PART_Indicator" HorizontalAlignment="Left" Background="{TemplateBinding Foreground}" CornerRadius="4"/></Grid>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="Nav" TargetType="ListBox">
      <Setter Property="Background" Value="Transparent"/><Setter Property="BorderThickness" Value="0"/>
      <Setter Property="ItemContainerStyle">
        <Setter.Value>
          <Style TargetType="ListBoxItem">
            <Setter Property="Foreground" Value="{StaticResource Muted}"/><Setter Property="Padding" Value="12,8"/><Setter Property="Margin" Value="8,1"/><Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
              <Setter.Value>
                <ControlTemplate TargetType="ListBoxItem">
                  <Border x:Name="b" Background="Transparent" CornerRadius="8" Padding="{TemplateBinding Padding}">
                    <StackPanel Orientation="Horizontal">
                      <TextBlock Text="{Binding Icon}" FontFamily="Segoe UI Emoji" Width="24" Foreground="{TemplateBinding Foreground}"/>
                      <TextBlock Text="{Binding Title}" Foreground="{TemplateBinding Foreground}" VerticalAlignment="Center"/>
                      <TextBlock Text="{Binding Count}" Foreground="{StaticResource Muted}" Margin="8,0,0,0" FontSize="11" VerticalAlignment="Center"/>
                    </StackPanel>
                  </Border>
                  <ControlTemplate.Triggers>
                    <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="{StaticResource Card}"/><Setter Property="Foreground" Value="{StaticResource Text}"/></Trigger>
                    <Trigger Property="IsSelected" Value="True"><Setter TargetName="b" Property="Background" Value="{StaticResource CardHover}"/><Setter Property="Foreground" Value="{StaticResource Text}"/></Trigger>
                  </ControlTemplate.Triggers>
                </ControlTemplate>
              </Setter.Value>
            </Setter>
          </Style>
        </Setter.Value>
      </Setter>
    </Style>
    <DataTemplate x:Key="TweakCard">
      <Border Background="{StaticResource Card}" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="10" Margin="0,0,0,8" Padding="14,10" Opacity="{Binding Opacity}" ToolTipService.ShowDuration="60000">
        <Border.ToolTip><ToolTip Background="#0B0D13" Foreground="#E6E8EF" BorderBrush="#2A2F45" MaxWidth="820"><TextBlock Text="{Binding Details}" FontFamily="Consolas" FontSize="11" TextWrapping="Wrap"/></ToolTip></Border.ToolTip>
        <Grid>
          <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <CheckBox Grid.Column="0" IsChecked="{Binding Selected, Mode=TwoWay}" IsEnabled="{Binding Applicable}" VerticalAlignment="Top" Margin="0,3,12,0"/>
          <StackPanel Grid.Column="1">
            <StackPanel Orientation="Horizontal">
              <Ellipse Width="9" Height="9" Fill="{Binding StateBrush}" Margin="0,0,8,0" VerticalAlignment="Center" ToolTip="{Binding StateText}"/>
              <TextBlock Text="{Binding Name}" FontWeight="SemiBold" FontSize="14"/>
              <Border Background="{Binding RiskBrush}" CornerRadius="10" Padding="7,1" Margin="10,0,0,0" VerticalAlignment="Center"><TextBlock Text="{Binding RiskText}" FontSize="10" Foreground="#0F1117" FontWeight="Bold"/></Border>
              <TextBlock Text="{Binding Badges}" Foreground="{StaticResource Muted}" FontSize="11" Margin="10,0,0,0" VerticalAlignment="Center"/>
            </StackPanel>
            <TextBlock Text="{Binding Description}" Foreground="{StaticResource Muted}" Margin="17,3,0,0" FontSize="12"/>
            <TextBlock Text="{Binding Reason}" Foreground="{StaticResource Yellow}" Margin="17,3,0,0" FontSize="11"/>
          </StackPanel>
          <TextBlock Grid.Column="2" Text="{Binding Id}" Foreground="#4A5069" FontSize="10" FontFamily="Consolas" VerticalAlignment="Top" Margin="12,4,0,0"/>
        </Grid>
      </Border>
    </DataTemplate>
    <DataTemplate x:Key="ProfileCard">
      <Border Background="{StaticResource Card}" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="12" Margin="0,0,12,12" Padding="18" Width="330" Height="190">
        <DockPanel>
          <StackPanel DockPanel.Dock="Bottom" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button Content="Preview" Tag="{Binding Id}" Name="BtnProfilePreview" Margin="0,0,8,0"/>
            <Button Content="Apply" Style="{StaticResource Primary}" Tag="{Binding Id}" Name="BtnProfileApply"/>
          </StackPanel>
          <StackPanel>
            <StackPanel Orientation="Horizontal">
              <TextBlock Text="{Binding Icon}" FontFamily="Segoe UI Emoji" FontSize="22" Margin="0,0,10,0"/>
              <TextBlock Text="{Binding Name}" FontSize="17" FontWeight="SemiBold" VerticalAlignment="Center"/>
              <TextBlock Text="{Binding Count}" Foreground="{StaticResource Muted}" Margin="10,0,0,0" VerticalAlignment="Center"/>
            </StackPanel>
            <TextBlock Text="{Binding Description}" Foreground="{StaticResource Muted}" Margin="0,8,0,0" FontSize="12"/>
          </StackPanel>
        </DockPanel>
      </Border>
    </DataTemplate>
  </Window.Resources>

  <Grid>
    <Grid.ColumnDefinitions><ColumnDefinition Width="220"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
    <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>

    <!-- sidebar -->
    <Border Grid.Column="0" Grid.RowSpan="2" Background="{StaticResource Panel}" BorderBrush="{StaticResource Border}" BorderThickness="0,0,1,0">
      <DockPanel>
        <StackPanel DockPanel.Dock="Top" Margin="18,18,18,10">
          <TextBlock FontSize="22" FontWeight="Bold"><Run Text="Win" Foreground="#E6E8EF"/><Run Text="Forge" Foreground="#4F8CFF"/></TextBlock>
          <TextBlock Name="LblVersion" Foreground="{StaticResource Muted}" FontSize="11"/>
        </StackPanel>
        <StackPanel DockPanel.Dock="Bottom" Margin="12">
          <TextBlock Name="LblOs" Foreground="{StaticResource Muted}" FontSize="11"/>
          <TextBlock Name="LblBuild" Foreground="{StaticResource Muted}" FontSize="11"/>
        </StackPanel>
        <ScrollViewer VerticalScrollBarVisibility="Auto"><ListBox Name="Nav" Style="{StaticResource Nav}"/></ScrollViewer>
      </DockPanel>
    </Border>

    <!-- main -->
    <Grid Grid.Column="1" Grid.Row="0" Margin="20,16,20,0">
      <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
      <Grid Grid.Row="0" Margin="0,0,0,12">
        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
        <StackPanel Orientation="Horizontal">
          <TextBlock Name="LblPage" FontSize="22" FontWeight="SemiBold" VerticalAlignment="Center"/>
          <TextBlock Name="LblPageSub" Foreground="{StaticResource Muted}" Margin="14,4,0,0" VerticalAlignment="Center"/>
        </StackPanel>
        <StackPanel Grid.Column="1" Orientation="Horizontal">
          <Border Background="{StaticResource Card}" CornerRadius="8" Padding="10,4" Margin="0,0,10,0" BorderBrush="{StaticResource Border}" BorderThickness="1">
            <StackPanel Orientation="Horizontal">
              <TextBlock Text="Score " Foreground="{StaticResource Muted}"/><TextBlock Name="LblScore" FontWeight="Bold" Foreground="{StaticResource Accent2}"/>
            </StackPanel>
          </Border>
          <TextBox Name="TxtSearch" Width="260" VerticalAlignment="Center"/>
        </StackPanel>
      </Grid>

      <Grid Grid.Row="1">
        <!-- Dashboard -->
        <ScrollViewer Name="PageDashboard" VerticalScrollBarVisibility="Auto">
          <StackPanel>
            <WrapPanel>
              <Border Background="{StaticResource Card}" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="12" Padding="18" Width="330" Margin="0,0,12,12">
                <StackPanel>
                  <TextBlock Text="🔒 Privacy" FontFamily="Segoe UI Emoji" FontSize="14" FontWeight="SemiBold"/>
                  <TextBlock Name="LblScorePrivacy" FontSize="34" FontWeight="Bold" Foreground="{StaticResource Accent2}"/>
                  <ProgressBar Name="BarPrivacy" Maximum="100" Foreground="{StaticResource Accent2}"/>
                </StackPanel>
              </Border>
              <Border Background="{StaticResource Card}" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="12" Padding="18" Width="330" Margin="0,0,12,12">
                <StackPanel>
                  <TextBlock Text="⚡ Performance" FontFamily="Segoe UI Emoji" FontSize="14" FontWeight="SemiBold"/>
                  <TextBlock Name="LblScorePerf" FontSize="34" FontWeight="Bold" Foreground="{StaticResource Yellow}"/>
                  <ProgressBar Name="BarPerf" Maximum="100" Foreground="{StaticResource Yellow}"/>
                </StackPanel>
              </Border>
              <Border Background="{StaticResource Card}" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="12" Padding="18" Width="330" Margin="0,0,12,12">
                <StackPanel>
                  <TextBlock Text="🧹 Clean" FontFamily="Segoe UI Emoji" FontSize="14" FontWeight="SemiBold"/>
                  <TextBlock Name="LblScoreBloat" FontSize="34" FontWeight="Bold" Foreground="{StaticResource Green}"/>
                  <ProgressBar Name="BarBloat" Maximum="100" Foreground="{StaticResource Green}"/>
                </StackPanel>
              </Border>
            </WrapPanel>
            <WrapPanel>
              <Border Background="{StaticResource Card}" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="12" Padding="18" Width="672" Margin="0,0,12,12">
                <StackPanel>
                  <TextBlock Text="System" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,8"/>
                  <TextBlock Name="LblSysInfo" Foreground="{StaticResource Muted}" FontFamily="Consolas" FontSize="12"/>
                </StackPanel>
              </Border>
              <Border Background="{StaticResource Card}" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="12" Padding="18" Width="330" Margin="0,0,12,12">
                <StackPanel>
                  <TextBlock Text="Quick actions" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,8"/>
                  <Button Name="BtnQuickBalanced" Content="⚖️  Apply Balanced profile" Style="{StaticResource Primary}" Margin="0,0,0,8" HorizontalAlignment="Stretch"/>
                  <Button Name="BtnQuickRestore" Content="🛟  Create restore point" Margin="0,0,0,8" HorizontalAlignment="Stretch"/>
                  <Button Name="BtnQuickScan" Content="🔄  Rescan state" Margin="0,0,0,8" HorizontalAlignment="Stretch"/>
                  <Button Name="BtnQuickUndo" Content="↩️  Undo last session" Style="{StaticResource Danger}" HorizontalAlignment="Stretch"/>
                </StackPanel>
              </Border>
            </WrapPanel>
          </StackPanel>
        </ScrollViewer>

        <!-- Tweaks -->
        <DockPanel Name="PageTweaks" Visibility="Collapsed">
          <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Margin="0,0,0,10">
            <Button Name="BtnSelectSafe" Content="Select all safe"/>
            <Button Name="BtnSelectNotApplied" Content="Select not applied" Margin="8,0,0,0"/>
            <Button Name="BtnClear" Content="Clear" Margin="8,0,0,0"/>
            <TextBlock Name="LblLegend" Foreground="{StaticResource Muted}" Margin="18,0,0,0" VerticalAlignment="Center" Text="●  applied     ◐  partial     ○  not applied"/>
          </StackPanel>
          <ScrollViewer VerticalScrollBarVisibility="Auto"><ItemsControl Name="ListTweaks" ItemTemplate="{StaticResource TweakCard}"/></ScrollViewer>
        </DockPanel>

        <!-- Profiles -->
        <ScrollViewer Name="PageProfiles" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
          <ItemsControl Name="ListProfiles" ItemTemplate="{StaticResource ProfileCard}">
            <ItemsControl.ItemsPanel><ItemsPanelTemplate><WrapPanel/></ItemsPanelTemplate></ItemsControl.ItemsPanel>
          </ItemsControl>
        </ScrollViewer>

        <!-- Apps -->
        <DockPanel Name="PageApps" Visibility="Collapsed">
          <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Margin="0,0,0,10">
            <Button Name="BtnAppsRefresh" Content="Refresh"/>
            <Button Name="BtnAppsRemove" Content="Remove selected" Style="{StaticResource Danger}" Margin="8,0,0,0"/>
            <CheckBox Name="ChkAppsMs" Content="Show Microsoft system packages" Margin="18,0,0,0"/>
          </StackPanel>
          <ListView Name="ListApps" SelectionMode="Extended">
            <ListView.View><GridView>
              <GridViewColumn Width="34"><GridViewColumn.CellTemplate><DataTemplate><CheckBox IsChecked="{Binding Selected, Mode=TwoWay}"/></DataTemplate></GridViewColumn.CellTemplate></GridViewColumn>
              <GridViewColumn Header="Package" Width="380" DisplayMemberBinding="{Binding Name}"/>
              <GridViewColumn Header="Publisher" Width="260" DisplayMemberBinding="{Binding Publisher}"/>
              <GridViewColumn Header="Version" Width="120" DisplayMemberBinding="{Binding Version}"/>
              <GridViewColumn Header="Provisioned" Width="90" DisplayMemberBinding="{Binding Provisioned}"/>
              <GridViewColumn Header="Bloat?" Width="70" DisplayMemberBinding="{Binding Known}"/>
            </GridView></ListView.View>
          </ListView>
        </DockPanel>

        <!-- Cleaner -->
        <DockPanel Name="PageCleaner" Visibility="Collapsed">
          <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Margin="0,0,0,10">
            <Button Name="BtnCleanScan" Content="Scan sizes"/>
            <Button Name="BtnCleanRun" Content="Clean selected" Style="{StaticResource Primary}" Margin="8,0,0,0"/>
            <TextBlock Name="LblCleanTotal" Foreground="{StaticResource Muted}" Margin="18,0,0,0" VerticalAlignment="Center"/>
          </StackPanel>
          <ListView Name="ListClean">
            <ListView.View><GridView>
              <GridViewColumn Width="34"><GridViewColumn.CellTemplate><DataTemplate><CheckBox IsChecked="{Binding Selected, Mode=TwoWay}"/></DataTemplate></GridViewColumn.CellTemplate></GridViewColumn>
              <GridViewColumn Header="Target" Width="260" DisplayMemberBinding="{Binding Name}"/>
              <GridViewColumn Header="Size (MB)" Width="110" DisplayMemberBinding="{Binding MB}"/>
              <GridViewColumn Header="Path" Width="520" DisplayMemberBinding="{Binding Path}"/>
            </GridView></ListView.View>
          </ListView>
        </DockPanel>

        <!-- Journal -->
        <DockPanel Name="PageJournal" Visibility="Collapsed">
          <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Margin="0,0,0,10">
            <Button Name="BtnJournalRefresh" Content="Refresh"/>
            <Button Name="BtnJournalRevert" Content="Revert selected session" Style="{StaticResource Danger}" Margin="8,0,0,0"/>
            <Button Name="BtnJournalOpen" Content="Open folder" Margin="8,0,0,0"/>
          </StackPanel>
          <ListView Name="ListJournal">
            <ListView.View><GridView>
              <GridViewColumn Header="Created" Width="180" DisplayMemberBinding="{Binding Created}"/>
              <GridViewColumn Header="Label" Width="200" DisplayMemberBinding="{Binding Label}"/>
              <GridViewColumn Header="Profile" Width="120" DisplayMemberBinding="{Binding Profile}"/>
              <GridViewColumn Header="Tweaks" Width="80" DisplayMemberBinding="{Binding Tweaks}"/>
              <GridViewColumn Header="Id" Width="300" DisplayMemberBinding="{Binding Id}"/>
            </GridView></ListView.View>
          </ListView>
        </DockPanel>

        <!-- Settings -->
        <ScrollViewer Name="PageSettings" Visibility="Collapsed">
          <StackPanel Width="560" HorizontalAlignment="Left">
            <Border Background="{StaticResource Card}" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="12" Padding="18" Margin="0,0,0,12">
              <StackPanel>
                <TextBlock Text="General" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,10"/>
                <StackPanel Orientation="Horizontal" Margin="0,0,0,10"><TextBlock Text="Language" Width="200" VerticalAlignment="Center"/><ComboBox Name="CmbLang" Width="140"><ComboBoxItem Content="English" Tag="en"/><ComboBoxItem Content="Українська" Tag="uk"/></ComboBox></StackPanel>
                <CheckBox Name="ChkRestore" Content="Create a restore point before applying" Margin="0,0,0,8"/>
                <CheckBox Name="ChkDefaultUser" Content="Also apply user tweaks to the Default profile (new accounts / sysprep)" Margin="0,0,0,8"/>
                <CheckBox Name="ChkPersist" Content="Persist: re-apply my tweaks after Windows updates (logon watchdog)" Margin="0,0,0,8"/>
              </StackPanel>
            </Border>
            <Border Background="{StaticResource Card}" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="12" Padding="18" Margin="0,0,0,12">
              <StackPanel>
                <TextBlock Text="Maintenance" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,10"/>
                <StackPanel Orientation="Horizontal">
                  <Button Name="BtnOpenLogs" Content="Open logs"/>
                  <Button Name="BtnExport" Content="Export selection as profile…" Margin="8,0,0,0"/>
                  <Button Name="BtnImport" Content="Import profile…" Margin="8,0,0,0"/>
                </StackPanel>
              </StackPanel>
            </Border>
            <Border Background="{StaticResource Card}" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="12" Padding="18">
              <StackPanel>
                <TextBlock Text="About" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,6"/>
                <TextBlock Name="LblAbout" Foreground="{StaticResource Muted}" FontSize="12"/>
              </StackPanel>
            </Border>
          </StackPanel>
        </ScrollViewer>
      </Grid>
    </Grid>

    <!-- bottom bar -->
    <Border Grid.Column="1" Grid.Row="1" Background="{StaticResource Panel}" BorderBrush="{StaticResource Border}" BorderThickness="0,1,0,0" Padding="20,10">
      <StackPanel>
        <Grid>
          <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <StackPanel Orientation="Horizontal">
            <TextBlock Name="LblSelected" VerticalAlignment="Center" Foreground="{StaticResource Muted}"/>
            <CheckBox Name="ChkDryRun" Content="Dry run" Margin="18,0,0,0"/>
            <TextBlock Name="LblBusy" Foreground="{StaticResource Accent2}" Margin="18,0,0,0" VerticalAlignment="Center"/>
            <ProgressBar Name="BarBusy" Width="180" Margin="12,0,0,0" VerticalAlignment="Center" Visibility="Collapsed"/>
          </StackPanel>
          <StackPanel Grid.Column="1" Orientation="Horizontal">
            <Button Name="BtnLog" Content="Log ▾"/>
            <Button Name="BtnRevert" Content="Revert selected" Style="{StaticResource Danger}" Margin="8,0,0,0"/>
            <Button Name="BtnApply" Content="Apply selected" Style="{StaticResource Primary}" Margin="8,0,0,0" MinWidth="150"/>
          </StackPanel>
        </Grid>
        <TextBox Name="TxtLog" Height="170" Margin="0,10,0,0" IsReadOnly="True" FontFamily="Consolas" FontSize="11" VerticalScrollBarVisibility="Auto" TextWrapping="NoWrap" Visibility="Collapsed" Background="#0B0D13"/>
      </StackPanel>
    </Border>
  </Grid>
</Window>
'@

function Start-ForgeGui {
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$script:Xaml)
    $w = [Windows.Markup.XamlReader]::Load($reader)
    $ui = @{}
    foreach ($n in ([regex]::Matches($script:Xaml, 'Name="(\w+)"') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)) { $ui[$n] = $w.FindName($n) }

    $root = (Get-ForgePaths).Root
    $cats = Get-ForgeCategories
    $catalog = Import-ForgeCatalog
    $os = Get-ForgeOsInfo
    $cfg = Get-ForgeConfig
    $brush = @{
        safe = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString('#34D399'))
        moderate = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString('#FBBF24'))
        advanced = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString('#F87171'))
        Applied = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString('#34D399'))
        Partial = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString('#FBBF24'))
        NotApplied = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString('#4A5069'))
        Unknown = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString('#2A2F45'))
    }

    # ---------------- shared state with the worker runspace
    $sync = [hashtable]::Synchronized(@{ Log = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue)); States = @{}; Busy = $false; Done = $false; Result = $null; Task = ''; Progress = 0 })
    $script:Worker = $null

    function Start-Worker {
        param([string]$Task, [hashtable]$WorkArgs)
        if ($sync.Busy) { return }
        $sync.Busy = $true; $sync.Done = $false; $sync.Task = $Task; $sync.Result = $null; $sync.Progress = 0
        $ui.LblBusy.Text = "⏳ $Task…"; $ui.BarBusy.Visibility = 'Visible'; $ui.BarBusy.IsIndeterminate = $true
        $ui.BtnApply.IsEnabled = $false; $ui.BtnRevert.IsEnabled = $false
        $rs = [runspacefactory]::CreateRunspace(); $rs.ApartmentState = 'STA'; $rs.Open()
        $rs.SessionStateProxy.SetVariable('Sync', $sync)
        $rs.SessionStateProxy.SetVariable('WfArgs', $WorkArgs)
        $rs.SessionStateProxy.SetVariable('Root', $root)
        $rs.SessionStateProxy.SetVariable('Task', $Task)
        $ps = [powershell]::Create(); $ps.Runspace = $rs
        [void]$ps.AddScript({
            try {
                if ($PSVersionTable.PSEdition -eq 'Core') { foreach ($m in 'Appx', 'Dism', 'ScheduledTasks') { try { Import-Module $m -UseWindowsPowerShell -WarningAction SilentlyContinue -ErrorAction Stop } catch { } } }
                Import-Module (Join-Path $Root 'src\WinForge.Core.psm1') -Force -DisableNameChecking
                Import-Module (Join-Path $Root 'src\WinForge.Catalog.psm1') -Force -DisableNameChecking
                Import-Module (Join-Path $Root 'src\WinForge.Diagnostics.psm1') -Force -DisableNameChecking
                Import-Module (Join-Path $Root 'src\WinForge.Session.psm1') -Force -DisableNameChecking
                . (Join-Path $Root 'src\WinForge.Persist.ps1')
                Set-ForgeLanguage $WfArgs.Lang; Set-ForgeDryRun ([bool]$WfArgs.DryRun); Set-ForgeQuiet $true
                Initialize-ForgeLog -Name 'gui' | Out-Null
                Set-ForgeUiSink { param($lvl, $msg) $Sync.Log.Enqueue("[$lvl] $msg") }
                $catalog = Import-ForgeCatalog
                switch ($Task) {
                    'scan' {
                        $i = 0
                        foreach ($t in $catalog) { $i++; $Sync.Progress = [int]($i * 100 / $catalog.Count); $Sync.States[$t.id] = Get-ForgeTweakState -Tweak $t }
                        $Sync.Result = Get-ForgeScore -Catalog $catalog -StateCache $Sync.States
                    }
                    'apply' {
                        $sel = Get-ForgeSelectionFromIds -Ids $WfArgs.Ids
                        $r = Invoke-ForgeSession -Tweaks $sel -Label $WfArgs.Label -Profile $WfArgs.Profile -NoRestorePoint:(-not $WfArgs.RestorePoint) -DefaultUser:([bool]$WfArgs.DefaultUser) -Progress { param($i, $n, $t) $Sync.Progress = [int]($i * 100 / $n) }
                        if ($WfArgs.Persist) { Register-ForgePersist -Ids @($sel.id) -Profile $WfArgs.Profile | Out-Null }
                        foreach ($t in $sel) { $Sync.States[$t.id] = Get-ForgeTweakState -Tweak $t }
                        $Sync.Result = $r
                    }
                    'revert' {
                        $sel = Get-ForgeSelectionFromIds -Ids $WfArgs.Ids
                        Invoke-ForgeRevertSession -Tweaks $sel -Progress { param($i, $n, $t) $Sync.Progress = [int]($i * 100 / $n) } | Out-Null
                        foreach ($t in $sel) { $Sync.States[$t.id] = Get-ForgeTweakState -Tweak $t }
                    }
                    'revertjournal' { New-ForgeJournal -Label 'revert' | Out-Null; Restore-ForgeJournal -File $WfArgs.File | Out-Null; Save-ForgeJournal | Out-Null }
                    'restorepoint' { New-ForgeRestorePoint -Description 'WinForge manual' | Out-Null }
                    'apps' { $Sync.Result = @(Get-ForgeAppxInventory) }
                    'removeapps' {
                        New-ForgeJournal -Label 'apps' | Out-Null
                        foreach ($n in $WfArgs.Names) { Write-ForgeLog "remove $n" -Level Step; Remove-ForgeAppx -TweakId 'gui.apps' -Name $n | Out-Null }
                        Save-ForgeJournal | Out-Null
                        $Sync.Result = @(Get-ForgeAppxInventory)
                    }
                    'cleanscan' { $Sync.Result = @(Get-ForgeCleanupTargets) }
                    'clean' { $mb = Invoke-ForgeCleanup -Ids $WfArgs.Ids; Write-ForgeLog "Freed ~$mb MB" -Level Ok; $Sync.Result = @(Get-ForgeCleanupTargets) }
                    'sysinfo' { $Sync.Result = Get-ForgeHealthReport -SkipScore }
                }
            } catch { $Sync.Log.Enqueue("[Error] $($_.Exception.Message)`n$($_.ScriptStackTrace)") }
            finally { $Sync.Done = $true }
        })
        $script:Worker = @{ PS = $ps; Handle = $ps.BeginInvoke(); RS = $rs }
    }

    # ---------------- view models
    $script:Vm = @{}
    function New-TweakVm {
        param($t)
        $reason = ''
        $ok = Test-ForgeTweakApplicable -Tweak $t -Os $os -Reason ([ref]$reason)
        $badges = @()
        if ($t.PSObject.Properties['reboot'] -and $t.reboot) { $badges += '⟳ reboot' }
        if ($t.PSObject.Properties['reversible'] -and $t.reversible -eq $false) { $badges += '⚠ not reversible' }
        if ($t.PSObject.Properties['minBuild'] -and $t.minBuild) { $badges += "build $($t.minBuild)+" }
        if ($t.PSObject.Properties['tags'] -and $t.tags -contains 'recommended') { $badges += '★ recommended' }
        $details = foreach ($a in $t.actions) {
            switch ($a.type) {
                'registry'          { "reg   $($a.path)!$($a.name) = $($a.value)" }
                'registryDelete'    { "reg   delete $($a.path)!$($a.name)" }
                'registryDeleteKey' { "reg   delete key $($a.path)" }
                'service'           { "svc   $($a.name) -> $(if ($a.PSObject.Properties['startup']) { $a.startup } else { 'Disabled' })" }
                'task'              { "task  $($a.path)$($a.name) -> disabled" }
                'appx'              { "appx  remove $($a.name)" }
                'feature'           { "dism  feature $($a.name) -> $($a.state)" }
                'capability'        { "dism  capability $($a.name) -> $($a.state)" }
                default             { $line = ($a.apply -replace '\s+', ' '); "$($a.type.PadRight(5)) $(if ($line.Length -gt 160) { $line.Substring(0, 160) + '…' } else { $line })" }
            }
        }
        [PSCustomObject]@{
            Id = $t.id; Category = $t.category; Name = (Get-LocalizedText $t.name); Description = (Get-LocalizedText $t.description)
            Details = ("$($t.id)`n" + ($details -join "`n"))
            Risk = $t.risk; RiskText = (Get-ForgeString "risk.$($t.risk)").ToUpper(); RiskBrush = $brush[$t.risk]
            State = 'Unknown'; StateBrush = $brush.Unknown; StateText = (Get-ForgeString 'state.unknown')
            Selected = $false; Applicable = $ok; Reason = $reason; Opacity = $(if ($ok) { 1.0 } else { 0.5 }); Badges = ($badges -join '   ')
            Tags = @(if ($t.PSObject.Properties['tags']) { $t.tags })
        }
    }
    foreach ($t in $catalog) { $script:Vm[$t.id] = New-TweakVm $t }
    $script:VmOrder = @($catalog.id)

    function Update-VmStates {
        foreach ($id in @($sync.States.Keys)) {
            $vm = $script:Vm[$id]; if (-not $vm) { continue }
            $s = $sync.States[$id]
            $vm.State = $s; $vm.StateBrush = $brush[$s]
            $vm.StateText = Get-ForgeString $(switch ($s) { 'Applied' { 'state.applied' } 'Partial' { 'state.partial' } 'NotApplied' { 'state.notapplied' } default { 'state.unknown' } })
        }
    }

    function Update-Score {
        param($score)
        if (-not $score) { return }
        $ui.LblScore.Text = "$($score.Overall)"
        $ui.LblScorePrivacy.Text = "$($score.Privacy)%"; $ui.BarPrivacy.Value = $score.Privacy
        $ui.LblScorePerf.Text = "$($score.Performance)%"; $ui.BarPerf.Value = $score.Performance
        $ui.LblScoreBloat.Text = "$($score.Bloat)%"; $ui.BarBloat.Value = $score.Bloat
    }

    $script:CurrentPage = 'dashboard'
    $script:CurrentCategory = ''
    function Show-Page {
        param([string]$Page)
        $script:CurrentPage = $Page
        foreach ($p in 'PageDashboard', 'PageTweaks', 'PageProfiles', 'PageApps', 'PageCleaner', 'PageJournal', 'PageSettings') { $ui[$p].Visibility = 'Collapsed' }
        switch ($Page) {
            'dashboard' { $ui.PageDashboard.Visibility = 'Visible'; $ui.LblPage.Text = Get-ForgeString 'gui.dashboard'; $ui.LblPageSub.Text = '' }
            'profiles'  { $ui.PageProfiles.Visibility = 'Visible'; $ui.LblPage.Text = Get-ForgeString 'gui.profiles'; $ui.LblPageSub.Text = '' }
            'apps'      { $ui.PageApps.Visibility = 'Visible'; $ui.LblPage.Text = Get-ForgeString 'gui.apps'; $ui.LblPageSub.Text = ''; if (-not $ui.ListApps.ItemsSource) { Start-Worker 'apps' @{ Lang = $cfg.language } } }
            'cleaner'   { $ui.PageCleaner.Visibility = 'Visible'; $ui.LblPage.Text = Get-ForgeString 'gui.cleaner'; $ui.LblPageSub.Text = ''; if (-not $ui.ListClean.ItemsSource) { Start-Worker 'cleanscan' @{ Lang = $cfg.language } } }
            'journal'   { $ui.PageJournal.Visibility = 'Visible'; $ui.LblPage.Text = Get-ForgeString 'gui.journal'; $ui.LblPageSub.Text = ''; Update-Journal }
            'settings'  { $ui.PageSettings.Visibility = 'Visible'; $ui.LblPage.Text = Get-ForgeString 'gui.settings'; $ui.LblPageSub.Text = '' }
            'preview'   { $ui.PageTweaks.Visibility = 'Visible'; $script:CurrentCategory = '' }
            'tweaks'    { $ui.PageTweaks.Visibility = 'Visible'; $script:CurrentCategory = ''; Update-TweakList }
            default     { $ui.PageTweaks.Visibility = 'Visible'; $ui.LblPage.Text = "$($cats[$Page].icon) $Page"; $script:CurrentCategory = $Page; Update-TweakList }
        }
    }

    function Update-TweakList {
        $q = $ui.TxtSearch.Text.Trim().ToLowerInvariant()
        $items = foreach ($id in $script:VmOrder) {
            $vm = $script:Vm[$id]
            if ($q) { if (-not ($vm.Name.ToLowerInvariant().Contains($q) -or $vm.Description.ToLowerInvariant().Contains($q) -or $vm.Id.Contains($q) -or ($vm.Tags -contains $q))) { continue } }
            elseif ($script:CurrentCategory -and $vm.Category -ne $script:CurrentCategory) { continue }
            $vm
        }
        $ui.ListTweaks.ItemsSource = @($items)
        $ui.LblPageSub.Text = "$(@($items).Count) tweaks"
        Update-SelectedCount
    }

    function Update-SelectedCount {
        $n = @($script:Vm.Values | Where-Object Selected).Count
        $ui.LblSelected.Text = Get-ForgeString 'gui.selected' @($n)
        $ui.BtnApply.IsEnabled = ($n -gt 0 -and -not $sync.Busy); $ui.BtnRevert.IsEnabled = $ui.BtnApply.IsEnabled
    }

    function Update-Journal {
        $ui.ListJournal.ItemsSource = @(Get-ForgeJournalList | Where-Object Label -ne 'revert' | ForEach-Object { [PSCustomObject]@{ Created = $_.Created.Substring(0, 19).Replace('T', ' '); Label = $_.Label; Profile = $_.Profile; Tweaks = $_.Tweaks; Id = $_.Id; File = $_.File } })
    }

    function Update-SysInfo {
        param($r)
        $gpu = ($r.Hardware.Gpu | ForEach-Object { "$($_.Name) ($($_.VramGB) GB)" }) -join ', '
        $disk = ($r.Hardware.Disks | ForEach-Object { "$($_.Name) $($_.Type) $($_.SizeGB)GB" }) -join ', '
        $ui.LblSysInfo.Text = @(
            "OS        $($r.Os.ProductName) $($r.Os.DisplayVersion)  build $($r.Os.FullBuild)  $($r.Os.Edition)"
            "CPU       $($r.Hardware.Cpu)  $($r.Hardware.Cores)C/$($r.Hardware.Threads)T"
            "RAM       $($r.Hardware.RamGB) GB   used $($r.Runtime.RamUsedPct)%"
            "GPU       $gpu"
            "Disk      $disk   free on $($env:SystemDrive): $($r.Hardware.SystemDriveFreeGB) GB"
            "Board     $($r.Hardware.Board)   BIOS $($r.Hardware.Bios)   SecureBoot $($r.Hardware.SecureBoot)   VBS $($r.Hardware.Vbs)"
            "Runtime   $($r.Runtime.Processes) processes · $($r.Runtime.RunningServices) services · $($r.Runtime.StartupEntries) startup · $($r.Runtime.AppxCount) appx · up $([int]$r.Hardware.Uptime.TotalHours)h"
            "Restore   $(if ($r.RestorePoints) { 'restore points present' } else { 'no restore points yet' })   Admin $($r.Admin)"
        ) -join "`n"
    }

    # ---------------- nav
    $navItems = New-Object System.Collections.ObjectModel.ObservableCollection[object]
    $navItems.Add([PSCustomObject]@{ Key = 'dashboard'; Icon = '🏠'; Title = (Get-ForgeString 'gui.dashboard'); Count = '' })
    $navItems.Add([PSCustomObject]@{ Key = 'profiles'; Icon = '✨'; Title = (Get-ForgeString 'gui.profiles'); Count = '' })
    foreach ($k in $cats.Keys) { $navItems.Add([PSCustomObject]@{ Key = $k; Icon = $cats[$k].icon; Title = $k; Count = "$(@($catalog | Where-Object category -eq $k).Count)" }) }
    $navItems.Add([PSCustomObject]@{ Key = 'apps'; Icon = '📦'; Title = (Get-ForgeString 'gui.apps'); Count = '' })
    $navItems.Add([PSCustomObject]@{ Key = 'cleaner'; Icon = '🧽'; Title = (Get-ForgeString 'gui.cleaner'); Count = '' })
    $navItems.Add([PSCustomObject]@{ Key = 'journal'; Icon = '↩️'; Title = (Get-ForgeString 'gui.journal'); Count = '' })
    $navItems.Add([PSCustomObject]@{ Key = 'settings'; Icon = '⚙️'; Title = (Get-ForgeString 'gui.settings'); Count = '' })
    $ui.Nav.ItemsSource = $navItems
    $ui.Nav.Add_SelectionChanged({ if ($ui.Nav.SelectedItem) { $ui.TxtSearch.Text = ''; Show-Page $ui.Nav.SelectedItem.Key } })

    # ---------------- profiles
    $profiles = Import-ForgeProfiles
    $ui.ListProfiles.ItemsSource = @($profiles | ForEach-Object { [PSCustomObject]@{ Id = $_.id; Icon = $_.icon; Name = (Get-LocalizedText $_.name); Description = (Get-LocalizedText $_.description); Count = "$((Resolve-ForgeProfile $_).Count) tweaks" } })
    $ui.ListProfiles.AddHandler([Windows.Controls.Button]::ClickEvent, [Windows.RoutedEventHandler]{
        param($s, $e)
        $btn = $e.OriginalSource; if ($btn -isnot [Windows.Controls.Button]) { return }
        $p = $profiles | Where-Object id -eq $btn.Tag | Select-Object -First 1
        $sel = Resolve-ForgeProfile $p
        foreach ($vm in $script:Vm.Values) { $vm.Selected = $false }
        foreach ($t in $sel) { if ($script:Vm[$t.id].Applicable) { $script:Vm[$t.id].Selected = $true } }
        if ($btn.Name -eq 'BtnProfilePreview') { $script:CurrentCategory = ''; $ui.Nav.SelectedItem = $null; $ui.TxtSearch.Text = ''; Show-Page 'preview' ; $ui.LblPage.Text = "$($p.icon) $(Get-LocalizedText $p.name)"; $ui.ListTweaks.ItemsSource = @($sel | ForEach-Object { $script:Vm[$_.id] }); $ui.LblPageSub.Text = "$($sel.Count) tweaks — review, then Apply selected"; Update-SelectedCount }
        else { Invoke-ApplySelected -Label "profile:$($p.id)" -Profile $p.id }
    })

    # ---------------- apply / revert
    function Invoke-ApplySelected {
        param([string]$Label = 'gui', [string]$Profile = '')
        $ids = @($script:Vm.Values | Where-Object Selected | ForEach-Object Id)
        if (-not $ids.Count) { return }
        $names = ($ids | ForEach-Object { '• ' + $script:Vm[$_].Name }) -join "`n"
        $risky = @($ids | Where-Object { $script:Vm[$_].Risk -eq 'advanced' }).Count
        $msg = "Apply $($ids.Count) tweak(s)?`n`n$(if ($names.Length -gt 900) { $names.Substring(0, 900) + "`n…" } else { $names })"
        if ($risky) { $msg += "`n`n⚠ $risky ADVANCED tweak(s) selected — read their descriptions." }
        if ($ui.ChkDryRun.IsChecked) { $msg += "`n`n(DRY RUN — nothing will change)" }
        $r = [Windows.MessageBox]::Show($w, $msg, 'WinForge', 'OKCancel', $(if ($risky) { 'Warning' } else { 'Question' }))
        if ($r -ne 'OK') { return }
        $ui.TxtLog.Visibility = 'Visible'
        Start-Worker 'apply' @{ Ids = $ids; Label = $Label; Profile = $Profile; Lang = $cfg.language; DryRun = [bool]$ui.ChkDryRun.IsChecked; RestorePoint = [bool]$ui.ChkRestore.IsChecked; DefaultUser = [bool]$ui.ChkDefaultUser.IsChecked; Persist = [bool]$ui.ChkPersist.IsChecked }
    }
    $ui.BtnApply.Add_Click({ Invoke-ApplySelected })
    $ui.BtnRevert.Add_Click({
        $ids = @($script:Vm.Values | Where-Object Selected | ForEach-Object Id)
        if (-not $ids.Count) { return }
        if ([Windows.MessageBox]::Show($w, "Revert $($ids.Count) tweak(s)?", 'WinForge', 'OKCancel', 'Question') -ne 'OK') { return }
        $ui.TxtLog.Visibility = 'Visible'
        Start-Worker 'revert' @{ Ids = $ids; Lang = $cfg.language; DryRun = [bool]$ui.ChkDryRun.IsChecked }
    })
    $ui.BtnSelectSafe.Add_Click({ foreach ($vm in $ui.ListTweaks.ItemsSource) { if ($vm.Risk -eq 'safe' -and $vm.Applicable) { $vm.Selected = $true } }; Update-TweakList })
    $ui.BtnSelectNotApplied.Add_Click({ foreach ($vm in $ui.ListTweaks.ItemsSource) { if ($vm.State -in 'NotApplied', 'Partial' -and $vm.Risk -ne 'advanced' -and $vm.Applicable) { $vm.Selected = $true } }; Update-TweakList })
    $ui.BtnClear.Add_Click({ foreach ($vm in $script:Vm.Values) { $vm.Selected = $false }; Update-TweakList })
    $ui.ListTweaks.AddHandler([Windows.Controls.CheckBox]::ClickEvent, [Windows.RoutedEventHandler]{ Update-SelectedCount })
    $ui.TxtSearch.Add_TextChanged({ if ($ui.TxtSearch.Text) { if ($script:CurrentPage -notin 'tweaks', 'preview') { $ui.Nav.SelectedItem = $null; Show-Page 'tweaks' }; $ui.LblPage.Text = '🔎 ' + $ui.TxtSearch.Text; $script:CurrentCategory = ''; Update-TweakList } })
    $ui.BtnLog.Add_Click({ $ui.TxtLog.Visibility = $(if ($ui.TxtLog.Visibility -eq 'Visible') { 'Collapsed' } else { 'Visible' }) })

    # ---------------- dashboard quick actions
    $ui.BtnQuickBalanced.Add_Click({ $p = $profiles | Where-Object id -eq 'balanced'; foreach ($vm in $script:Vm.Values) { $vm.Selected = $false }; foreach ($t in (Resolve-ForgeProfile $p)) { if ($script:Vm[$t.id].Applicable) { $script:Vm[$t.id].Selected = $true } }; Invoke-ApplySelected -Label 'profile:balanced' -Profile 'balanced' })
    $ui.BtnQuickRestore.Add_Click({ $ui.TxtLog.Visibility = 'Visible'; Start-Worker 'restorepoint' @{ Lang = $cfg.language } })
    $ui.BtnQuickScan.Add_Click({ Start-Worker 'scan' @{ Lang = $cfg.language } })
    $ui.BtnQuickUndo.Add_Click({
        $j = Get-ForgeJournalList | Where-Object Label -ne 'revert' | Select-Object -First 1
        if (-not $j) { [Windows.MessageBox]::Show($w, 'No sessions to undo yet.', 'WinForge') | Out-Null; return }
        if ([Windows.MessageBox]::Show($w, "Undo session $($j.Id) ($($j.Tweaks) tweaks)?", 'WinForge', 'OKCancel', 'Warning') -ne 'OK') { return }
        $ui.TxtLog.Visibility = 'Visible'; Start-Worker 'revertjournal' @{ File = $j.File; Lang = $cfg.language }
    })

    # ---------------- apps
    $knownBloat = @($catalog | Where-Object category -eq 'bloatware' | ForEach-Object { $_.actions } | Where-Object type -eq 'appx' | ForEach-Object name)
    function Update-Apps {
        param($inv)
        $showMs = [bool]$ui.ChkAppsMs.IsChecked
        $ui.ListApps.ItemsSource = @($inv | Where-Object { $showMs -or -not ($_.Name -match '^(Microsoft\.(VCLibs|NET|UI\.Xaml|Services\.Store|WindowsAppRuntime|DirectX|Advertising|WindowsStore|DesktopAppInstaller|SecHealthUI|Windows\.ShellExperienceHost|Windows\.StartMenuExperienceHost|AAD|AccountsControl|LockApp|Win32WebViewHost|CredDialogHost|ECApp|BioEnrollment|WindowsTerminal|Windows\.Search|Windows\.Client|Windows\.Photos|WindowsCalculator|WindowsNotepad|Paint|ScreenSketch|HEIF|VP9|WebMedia|WebpImage|AV1|MPEG2|RawImage|HEVC|Windows\.CloudExperienceHost|Windows\.NarratorQuickStart|Windows\.PeopleExperienceHost|Windows\.PinningConfirmationDialog|Windows\.XGpuEjectDialog|Windows\.CapturePicker|Windows\.ContentDeliveryManager|Windows\.OOBENetworkCaptivePortal|Windows\.OOBENetworkConnectionFlow|Windows\.PrintQueueActionCenter|Windows\.SecureAssessmentBrowser|Windows\.CallingShellApp|Windows\.ParentalControls|Windows\.AssignedAccessLockApp|Windows\.Apprep|Windows\.FilePicker|Windows\.FileExplorer|Windows\.AppResolverUX|Windows\.AsyncTextService|Windows\.ShellExperienceHost)|MicrosoftWindows\.(Client\.(CBS|Core|FileExp|OOBE|WebExperience|Photon)|UndockedDevKit|LKG)|Windows\.(CBSPreview|PrintDialog|immersivecontrolpanel)|NcsiUwpApp|E2A4F912|F46D4000|1527c705|c5e2524a|Microsoft\.Windows\.Search|Microsoft\.Windows\.Cortana)') } |
            ForEach-Object { $name = $_.Name; $isKnown = @($knownBloat | Where-Object { $name -like $_ }).Count -gt 0
                [PSCustomObject]@{ Selected = $false; Name = $name; Publisher = ($_.Publisher -replace '^CN=', '' -split ',')[0]; Version = $_.Version; Provisioned = $_.Provisioned; Known = $(if ($isKnown) { 'yes' } else { '' }) } })
    }
    $ui.BtnAppsRefresh.Add_Click({ Start-Worker 'apps' @{ Lang = $cfg.language } })
    $ui.ChkAppsMs.Add_Click({ if ($script:AppInv) { Update-Apps $script:AppInv } })
    $ui.BtnAppsRemove.Add_Click({
        $names = @($ui.ListApps.ItemsSource | Where-Object Selected | ForEach-Object Name)
        if (-not $names.Count) { return }
        if ([Windows.MessageBox]::Show($w, "Remove $($names.Count) package(s) for all users?`n`n" + ($names -join "`n"), 'WinForge', 'OKCancel', 'Warning') -ne 'OK') { return }
        $ui.TxtLog.Visibility = 'Visible'; Start-Worker 'removeapps' @{ Names = $names; Lang = $cfg.language; DryRun = [bool]$ui.ChkDryRun.IsChecked }
    })

    # ---------------- cleaner
    function Update-Clean { param($targets) $ui.ListClean.ItemsSource = @($targets | ForEach-Object { [PSCustomObject]@{ Selected = ($_.Id -ne 'logs'); Id = $_.Id; Name = $_.Name; MB = $_.MB; Path = $_.Path } }); $ui.LblCleanTotal.Text = "total $([math]::Round(($targets | Measure-Object MB -Sum).Sum)) MB" }
    $ui.BtnCleanScan.Add_Click({ Start-Worker 'cleanscan' @{ Lang = $cfg.language } })
    $ui.BtnCleanRun.Add_Click({ $ids = @($ui.ListClean.ItemsSource | Where-Object Selected | ForEach-Object Id); if ($ids.Count) { $ui.TxtLog.Visibility = 'Visible'; Start-Worker 'clean' @{ Ids = $ids; Lang = $cfg.language; DryRun = [bool]$ui.ChkDryRun.IsChecked } } })

    # ---------------- journal
    $ui.BtnJournalRefresh.Add_Click({ Update-Journal })
    $ui.BtnJournalOpen.Add_Click({ Start-Process explorer.exe (Get-ForgePaths).Journal })
    $ui.BtnJournalRevert.Add_Click({
        $j = $ui.ListJournal.SelectedItem; if (-not $j) { return }
        if ([Windows.MessageBox]::Show($w, "Revert all $($j.Tweaks) tweak(s) from $($j.Id)?", 'WinForge', 'OKCancel', 'Warning') -ne 'OK') { return }
        $ui.TxtLog.Visibility = 'Visible'; Start-Worker 'revertjournal' @{ File = $j.File; Lang = $cfg.language; DryRun = [bool]$ui.ChkDryRun.IsChecked }
    })

    # ---------------- settings
    foreach ($item in $ui.CmbLang.Items) { if ($item.Tag -eq $cfg.language) { $ui.CmbLang.SelectedItem = $item } }
    $ui.ChkRestore.IsChecked = [bool]$cfg.createRestorePoint
    $ui.ChkPersist.IsChecked = (Test-ForgePersistRegistered)
    $ui.CmbLang.Add_SelectionChanged({ $cfg.language = $ui.CmbLang.SelectedItem.Tag; Save-ForgeConfig $cfg; [Windows.MessageBox]::Show($w, 'Language saved. Restart WinForge to apply.', 'WinForge') | Out-Null })
    $ui.ChkRestore.Add_Click({ $cfg.createRestorePoint = [bool]$ui.ChkRestore.IsChecked; Save-ForgeConfig $cfg })
    $ui.ChkPersist.Add_Click({ if (-not $ui.ChkPersist.IsChecked) { Unregister-ForgePersist } else { $st = Get-ForgePersistState; if ($st -and $st.ids) { Register-ForgePersist -Ids @($st.ids) -Profile $st.profile | Out-Null } else { [Windows.MessageBox]::Show($w, 'Persist will be registered with the tweaks you apply next.', 'WinForge') | Out-Null } } })
    $ui.BtnOpenLogs.Add_Click({ Start-Process explorer.exe (Get-ForgePaths).Logs })
    $ui.BtnExport.Add_Click({
        $ids = @($script:Vm.Values | Where-Object Selected | ForEach-Object Id); if (-not $ids.Count) { [Windows.MessageBox]::Show($w, 'Select some tweaks first.', 'WinForge') | Out-Null; return }
        $d = New-Object Microsoft.Win32.SaveFileDialog; $d.Filter = 'WinForge profile (*.json)|*.json'; $d.FileName = 'my-profile.json'
        if ($d.ShowDialog()) { Export-ForgeSelection -Ids $ids -Path $d.FileName -Name ([IO.Path]::GetFileNameWithoutExtension($d.FileName)) }
    })
    $ui.BtnImport.Add_Click({
        $d = New-Object Microsoft.Win32.OpenFileDialog; $d.Filter = 'WinForge profile (*.json)|*.json'
        if ($d.ShowDialog()) {
            $p = Get-Content -LiteralPath $d.FileName -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($vm in $script:Vm.Values) { $vm.Selected = $false }
            foreach ($t in (Resolve-ForgeProfile $p)) { if ($script:Vm[$t.id].Applicable) { $script:Vm[$t.id].Selected = $true } }
            $ui.Nav.SelectedItem = $null; Show-Page 'preview'; $ui.LblPage.Text = "📄 $($p.id)"; $ui.ListTweaks.ItemsSource = @($script:Vm.Values | Where-Object Selected); Update-SelectedCount
        }
    })
    $ui.LblAbout.Text = "WinForge $((Get-ForgePaths).Version) · $($catalog.Count) tweaks · $($profiles.Count) profiles`nData: $((Get-ForgePaths).Data)`nMIT License · github.com/v1rus91/WinForge"

    # ---------------- timer: drain worker output
    $timer = New-Object Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(200)
    $timer.Add_Tick({
        while ($sync.Log.Count -gt 0) { $ui.TxtLog.AppendText($sync.Log.Dequeue() + "`r`n"); $ui.TxtLog.ScrollToEnd() }
        if ($sync.Busy -and $sync.Progress -gt 0) { $ui.BarBusy.IsIndeterminate = $false; $ui.BarBusy.Value = $sync.Progress }
        if ($sync.Busy -and $sync.Done) {
            $sync.Busy = $false
            $task = $sync.Task
            $ui.LblBusy.Text = ''; $ui.BarBusy.Visibility = 'Collapsed'
            try { if ($script:Worker) { $script:Worker.PS.EndInvoke($script:Worker.Handle) | Out-Null; $script:Worker.PS.Dispose(); $script:Worker.RS.Close() } } catch { }
            switch ($task) {
                'scan'   { Update-VmStates; Update-Score $sync.Result; Update-TweakList; $ui.LblBusy.Text = '' }
                'apply'  { Update-VmStates; foreach ($vm in $script:Vm.Values) { $vm.Selected = $false }; Update-TweakList; $r = $sync.Result
                           if ($r) { $ui.LblBusy.Text = (Get-ForgeString 'msg.done' @($r.Applied, $r.Skipped, $r.Failed)); if ($r.Reboot -and -not $ui.ChkDryRun.IsChecked) { if ([Windows.MessageBox]::Show($w, (Get-ForgeString 'msg.reboot') + "`n`nReboot now?", 'WinForge', 'YesNo', 'Question') -eq 'Yes') { Restart-Computer -Force } } }
                           Start-Worker 'scan' @{ Lang = $cfg.language } }
                'revert' { Update-VmStates; foreach ($vm in $script:Vm.Values) { $vm.Selected = $false }; Update-TweakList; Start-Worker 'scan' @{ Lang = $cfg.language } }
                'revertjournal' { Update-Journal; Start-Worker 'scan' @{ Lang = $cfg.language } }
                'apps'   { $script:AppInv = $sync.Result; Update-Apps $script:AppInv }
                'removeapps' { $script:AppInv = $sync.Result; Update-Apps $script:AppInv }
                'cleanscan' { Update-Clean $sync.Result }
                'clean'  { Update-Clean $sync.Result }
                'sysinfo' { Update-SysInfo $sync.Result; Start-Worker 'scan' @{ Lang = $cfg.language } }
                default  { }
            }
            Update-SelectedCount
        }
    })

    # ---------------- init
    $ui.LblVersion.Text = "v$((Get-ForgePaths).Version)"
    $ui.LblOs.Text = "$($os.ProductName) $($os.DisplayVersion)"
    $ui.LblBuild.Text = "build $($os.FullBuild) · $($os.Edition)"
    $ui.TxtSearch.Tag = Get-ForgeString 'gui.search'
    $ui.LblScore.Text = '…'; $ui.LblScorePrivacy.Text = '…'; $ui.LblScorePerf.Text = '…'; $ui.LblScoreBloat.Text = '…'
    $ui.LblSysInfo.Text = 'collecting…'
    Show-Page 'dashboard'; $ui.Nav.SelectedIndex = 0
    $w.Add_Loaded({ $timer.Start(); Start-Worker 'sysinfo' @{ Lang = $cfg.language } })
    $w.Add_Closing({ param($s, $e) if ($sync.Busy) { if ([Windows.MessageBox]::Show($w, 'An operation is still running. Quit anyway?', 'WinForge', 'YesNo', 'Warning') -ne 'Yes') { $e.Cancel = $true } } })
    [void]$w.ShowDialog()
}
