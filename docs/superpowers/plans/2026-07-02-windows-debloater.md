# Windows Debloater Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a PowerShell WPF GUI tool that VITS IT techs can launch via a one-liner to debloat, install apps, run updates, and apply system tweaks on new Windows machines.

**Architecture:** `Run.ps1` is the entry point - handles execution policy bypass, elevation prompt, downloads `GUI.ps1` and `config.json` from GitHub raw, then launches the GUI. `GUI.ps1` loads the config, scans the machine, and renders a dark-mode WPF window with 5 tabs. `config.json` is the only file techs need to edit to add/remove apps.

**Tech Stack:** PowerShell 5.1+ (built into Windows 11), WPF via `System.Windows` assemblies (built into .NET Framework on Windows), winget (built into Windows 11), `Get-AppxPackage` (built-in PowerShell cmdlet)

---

## File Map

| File | Responsibility |
|---|---|
| `Run.ps1` | Entry point: execution policy, elevation, download, launch |
| `GUI.ps1` | WPF GUI: all 5 tabs, scanning, operations, runspace threading |
| `config.json` | All app/tweak data - the only file to edit for maintenance |

---

### Task 1: Create config.json with all app data

**Files:**
- Create: `config.json`

- [ ] **Step 1: Create config.json**

```json
{
  "version": "1.0.0",
  "debloat": [
    { "name": "Lenovo AI Now",              "type": "winget", "id": "Lenovo.AIPlugin" },
    { "name": "Lenovo Smart Meeting",        "type": "winget", "id": "Lenovo.SmartMeeting" },
    { "name": "Lenovo Speech",               "type": "winget", "id": "Lenovo.Speech" },
    { "name": "Xbox Game Bar",               "type": "appx",   "id": "Microsoft.XboxGamingOverlay" },
    { "name": "Xbox Game Pass",              "type": "appx",   "id": "Microsoft.GamingApp" },
    { "name": "Xbox App",                    "type": "appx",   "id": "Microsoft.XboxApp" },
    { "name": "Xbox Identity Provider",      "type": "appx",   "id": "Microsoft.XboxIdentityProvider" },
    { "name": "Microsoft Cortana",           "type": "appx",   "id": "Microsoft.549981C3F5F10" },
    { "name": "Microsoft Clipchamp",         "type": "appx",   "id": "Clipchamp.Clipchamp" },
    { "name": "Microsoft Tips",              "type": "appx",   "id": "Microsoft.Getstarted" },
    { "name": "Microsoft Weather",           "type": "appx",   "id": "Microsoft.BingWeather" },
    { "name": "Microsoft News",              "type": "appx",   "id": "Microsoft.BingNews" },
    { "name": "Microsoft Maps",              "type": "appx",   "id": "Microsoft.WindowsMaps" },
    { "name": "Microsoft Solitaire Collection", "type": "appx", "id": "Microsoft.MicrosoftSolitaireCollection" }
  ],
  "install": [
    { "name": "Google Chrome",        "id": "Google.Chrome" },
    { "name": "Mozilla Firefox",      "id": "Mozilla.Firefox" },
    { "name": "7-Zip",                "id": "7zip.7zip" },
    { "name": "Adobe Acrobat Reader", "id": "Adobe.Acrobat.Reader.64-bit" },
    { "name": "Notepad++",            "id": "Notepad++.Notepad++" },
    { "name": "VLC",                  "id": "VideoLAN.VLC" },
    { "name": "Microsoft 365",        "id": "Microsoft.Office" },
    { "name": "Microsoft Teams",      "id": "Microsoft.Teams" },
    { "name": "Bitwarden",            "id": "Bitwarden.Bitwarden" },
    { "name": "LastPass",             "id": "LastPass.LastPass" },
    { "name": "Dropbox",              "id": "Dropbox.Dropbox" },
    { "name": "Everything (Void Tools)", "id": "voidtools.Everything" },
    { "name": "PowerShell (latest)",  "id": "Microsoft.PowerShell" },
    { "name": "Python 3 (latest)",    "id": "Python.Python.3" },
    { "name": "Signal",               "id": "OpenWhisperSystems.Signal" },
    { "name": "Windows Terminal",     "id": "Microsoft.WindowsTerminal" },
    { "name": "Webex (Cisco)",        "id": "Cisco.WebexMeetings" },
    { "name": "WhatsApp",             "id": "WhatsApp.WhatsApp" },
    { "name": "VS Code",              "id": "Microsoft.VisualStudioCode" },
    { "name": "Power BI Desktop",     "id": "Microsoft.PowerBIDesktop" },
    { "name": "Git for Windows",      "id": "Git.Git" }
  ],
  "tweaks": [
    {
      "name": "Disable Fast Startup",
      "key": "DisableFastStartup",
      "description": "Prevents Windows from using hybrid shutdown, ensuring a full restart each time."
    },
    {
      "name": "Disable Windows Tips & Suggestions",
      "key": "DisableTips",
      "description": "Removes Microsoft promotional content from the Start Menu and lock screen."
    },
    {
      "name": "Disable Telemetry & Data Collection",
      "key": "DisableTelemetry",
      "description": "Reduces data sent to Microsoft by setting telemetry to Security level and disabling related scheduled tasks."
    },
    {
      "name": "Disable Bing Search in Start Menu",
      "key": "DisableBingSearch",
      "description": "Stops Start Menu searches from querying Bing."
    },
    {
      "name": "Set Power Plan to High Performance",
      "key": "HighPerformance",
      "description": "Activates the High Performance power plan for maximum responsiveness."
    },
    {
      "name": "Set Chrome as Default Browser",
      "key": "ChromeDefault",
      "description": "Opens Windows Default Apps settings so you can manually set Chrome as the default browser."
    }
  ]
}
```

- [ ] **Step 2: Commit**

```bash
git add config.json
git commit -m "feat: add config.json with full app and tweak lists"
```

---

### Task 2: Create Run.ps1 (entry point)

**Files:**
- Create: `Run.ps1`

- [ ] **Step 1: Create Run.ps1**

```powershell
#Requires -Version 5.1
Set-ExecutionPolicy Bypass -Scope Process -Force

$BaseUrl = "https://raw.githubusercontent.com/VITS-Ltd/Windows-Debloater/main"
$TempDir = "$env:TEMP\VITSDebloater"

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Add-Type -AssemblyName PresentationFramework
    $result = [System.Windows.MessageBox]::Show(
        "This tool requires administrator rights.`n`nRelaunch as Administrator now?",
        "VITS Windows Debloater",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )
    if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm $BaseUrl/Run.ps1 | iex`"" -Verb RunAs
    }
    exit
}

if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
}

Write-Host "Downloading latest files..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$BaseUrl/GUI.ps1"     -OutFile "$TempDir\GUI.ps1"     -UseBasicParsing
    Invoke-WebRequest -Uri "$BaseUrl/config.json" -OutFile "$TempDir\config.json" -UseBasicParsing
} catch {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show(
        "Failed to download files from GitHub.`n`nCheck your internet connection and try again.`n`nError: $_",
        "VITS Windows Debloater - Download Failed",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Error
    )
    exit 1
}

. "$TempDir\GUI.ps1"
Start-VITSDebloater -ConfigPath "$TempDir\config.json"
```

- [ ] **Step 2: Commit**

```bash
git add Run.ps1
git commit -m "feat: add Run.ps1 entry point with elevation and download"
```

---

### Task 3: Create GUI.ps1 - shell, theme, header

**Files:**
- Create: `GUI.ps1`

This task creates the WPF window skeleton with the dark theme, header bar, and tab control. No tab content yet.

- [ ] **Step 1: Create GUI.ps1 with window shell**

```powershell
function Start-VITSDebloater {
    param([string]$ConfigPath)

    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase

    $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

    [xml]$Xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="VITS Windows Debloater"
    Height="700" Width="900"
    MinHeight="600" MinWidth="800"
    WindowStartupLocation="CenterScreen"
    Background="#1E1E1E">

    <Window.Resources>
        <Style TargetType="TabItem">
            <Setter Property="Background" Value="#2D2D2D"/>
            <Setter Property="Foreground" Value="#F0F0F0"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="16,8"/>
            <Setter Property="FontSize" Value="13"/>
            <Style.Triggers>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="#0078D4"/>
                    <Setter Property="Foreground" Value="#FFFFFF"/>
                </Trigger>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#3E3E3E"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#0078D4"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="20,8"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#106EBE"/>
                </Trigger>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Background" Value="#3E3E3E"/>
                    <Setter Property="Foreground" Value="#888888"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#F0F0F0"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Margin" Value="0,4"/>
        </Style>
        <Style TargetType="ScrollViewer">
            <Setter Property="Background" Value="#1A1A1A"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#1A1A1A"/>
            <Setter Property="Foreground" Value="#B0FFB0"/>
            <Setter Property="FontFamily" Value="Consolas"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="#3E3E3E"/>
        </Style>
    </Window.Resources>

    <DockPanel>
        <!-- Header -->
        <Border DockPanel.Dock="Top" Background="#2D2D2D" Padding="20,12">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0" Orientation="Vertical">
                    <TextBlock Text="VITS Windows Debloater" FontSize="20" FontWeight="Bold" Foreground="#F0F0F0"/>
                    <TextBlock x:Name="MachineInfoText" FontSize="12" Foreground="#888888" Margin="0,2,0,0"/>
                </StackPanel>
                <TextBlock Grid.Column="1" Text="VITS" FontSize="22" FontWeight="Bold" Foreground="#0078D4" VerticalAlignment="Center"/>
            </Grid>
        </Border>

        <!-- Tab Control -->
        <TabControl x:Name="MainTabControl" Background="#1E1E1E" BorderThickness="0" Padding="0">
            <TabItem Header="Debloat"  x:Name="TabDebloat">
                <Grid x:Name="DebloatGrid" Background="#1E1E1E"/>
            </TabItem>
            <TabItem Header="Install"  x:Name="TabInstall">
                <Grid x:Name="InstallGrid" Background="#1E1E1E"/>
            </TabItem>
            <TabItem Header="Updates"  x:Name="TabUpdates">
                <Grid x:Name="UpdatesGrid" Background="#1E1E1E"/>
            </TabItem>
            <TabItem Header="Tweaks"   x:Name="TabTweaks">
                <Grid x:Name="TweaksGrid" Background="#1E1E1E"/>
            </TabItem>
            <TabItem Header="About"    x:Name="TabAbout">
                <Grid x:Name="AboutGrid" Background="#1E1E1E"/>
            </TabItem>
        </TabControl>
    </DockPanel>
</Window>
"@

    $Reader = [System.Xml.XmlNodeReader]::new($Xaml)
    $Window = [Windows.Markup.XamlReader]::Load($Reader)

    $MachineInfoText = $Window.FindName("MachineInfoText")
    $MachineInfoText.Text = "Host: $env:COMPUTERNAME   |   User: $env:USERNAME"

    $DebloatGrid  = $Window.FindName("DebloatGrid")
    $InstallGrid  = $Window.FindName("InstallGrid")
    $UpdatesGrid  = $Window.FindName("UpdatesGrid")
    $TweaksGrid   = $Window.FindName("TweaksGrid")
    $AboutGrid    = $Window.FindName("AboutGrid")

    # Tab content built in subsequent tasks - placeholders here
    # (each Build-*Tab function adds children to the grid)
    Build-DebloatTab  -Grid $DebloatGrid  -Config $Config -Window $Window
    Build-InstallTab  -Grid $InstallGrid  -Config $Config -Window $Window
    Build-UpdatesTab  -Grid $UpdatesGrid  -Window $Window
    Build-TweaksTab   -Grid $TweaksGrid   -Config $Config -Window $Window
    Build-AboutTab    -Grid $AboutGrid    -Config $Config

    $Window.ShowDialog() | Out-Null
}
```

- [ ] **Step 2: Commit**

```bash
git add GUI.ps1
git commit -m "feat: add GUI.ps1 shell with dark theme WPF window and header"
```

---

### Task 4: Implement helper - New-LogPanel and Invoke-InRunspace

**Files:**
- Modify: `GUI.ps1` (add above `Start-VITSDebloater`)

These two helpers are used by every tab that runs operations. Add them at the top of GUI.ps1, before the `Start-VITSDebloater` function.

- [ ] **Step 1: Add New-LogPanel helper**

`New-LogPanel` returns a `[System.Windows.Controls.TextBox]` configured as a read-only scrolling log. Tabs embed this in their grid.

Add this function at the top of GUI.ps1, before `Start-VITSDebloater`:

```powershell
function New-LogPanel {
    $tb = [System.Windows.Controls.TextBox]::new()
    $tb.IsReadOnly      = $true
    $tb.TextWrapping    = [System.Windows.TextWrapping]::Wrap
    $tb.VerticalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
    $tb.Background      = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1A1A1A")
    $tb.Foreground      = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#B0FFB0")
    $tb.FontFamily      = [System.Windows.Media.FontFamily]::new("Consolas")
    $tb.FontSize        = 12
    $tb.BorderThickness = [System.Windows.Thickness]::new(1)
    $tb.BorderBrush     = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#3E3E3E")
    $tb.Padding         = [System.Windows.Thickness]::new(8)
    return $tb
}
```

- [ ] **Step 2: Add Write-Log helper**

Add immediately after `New-LogPanel`:

```powershell
function Write-Log {
    param($LogBox, [string]$Message)
    $LogBox.Dispatcher.Invoke([Action]{
        $LogBox.AppendText("$Message`n")
        $LogBox.ScrollToEnd()
    })
}
```

- [ ] **Step 3: Add Invoke-InRunspace helper**

This runs a scriptblock in a background runspace, piping output back to `Write-Log` on the UI thread. The `$OnComplete` scriptblock runs on the UI thread when done.

Add immediately after `Write-Log`:

```powershell
function Invoke-InRunspace {
    param(
        [System.Windows.Controls.TextBox]$LogBox,
        [System.Windows.Controls.Button]$Button,
        [scriptblock]$Work,
        [scriptblock]$OnComplete = {}
    )

    $Button.IsEnabled = $false

    $Runspace = [runspacefactory]::CreateRunspace()
    $Runspace.ApartmentState = [System.Threading.ApartmentState]::STA
    $Runspace.ThreadOptions   = [System.Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
    $Runspace.Open()

    $PS = [powershell]::Create()
    $PS.Runspace = $Runspace

    $PS.AddScript({
        param($Work, $LogBox)
        & $Work | ForEach-Object {
            Write-Log -LogBox $LogBox -Message $_
        }
    }).AddArgument($Work).AddArgument($LogBox) | Out-Null

    $Handle = $PS.BeginInvoke()

    $Timer = [System.Windows.Threading.DispatcherTimer]::new()
    $Timer.Interval = [TimeSpan]::FromMilliseconds(200)
    $Timer.Add_Tick({
        if ($Handle.IsCompleted) {
            $Timer.Stop()
            try { $PS.EndInvoke($Handle) } catch {}
            $PS.Dispose()
            $Runspace.Close()
            $Button.IsEnabled = $true
            & $OnComplete
        }
    })
    $Timer.Start()
}
```

- [ ] **Step 4: Commit**

```bash
git add GUI.ps1
git commit -m "feat: add New-LogPanel, Write-Log, Invoke-InRunspace helpers"
```

---

### Task 5: Implement Build-DebloatTab

**Files:**
- Modify: `GUI.ps1` (add before `Start-VITSDebloater`)

- [ ] **Step 1: Add the machine scan helper**

Add before `Start-VITSDebloater`:

```powershell
function Get-InstalledDebloatItems {
    param($DebloatList)

    $WingetOutput = & winget list 2>&1 | Out-String
    $AppxPackages  = Get-AppxPackage -AllUsers | Select-Object -ExpandProperty Name

    $installed = @()
    foreach ($item in $DebloatList) {
        $found = $false
        if ($item.type -eq "winget") {
            if ($WingetOutput -match [regex]::Escape($item.id)) { $found = $true }
        } elseif ($item.type -eq "appx") {
            if ($AppxPackages -contains $item.id) { $found = $true }
        } elseif ($item.type -eq "both") {
            if (($WingetOutput -match [regex]::Escape($item.id)) -or ($AppxPackages -contains $item.id)) { $found = $true }
        }
        if ($found) { $installed += $item }
    }
    return $installed
}
```

- [ ] **Step 2: Add Build-DebloatTab function**

Add after the scan helper:

```powershell
function Build-DebloatTab {
    param($Grid, $Config, $Window)

    $Grid.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new()) # row 0: label
    $rd1 = [System.Windows.Controls.RowDefinition]::new(); $rd1.Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $Grid.RowDefinitions.Add($rd1) # row 1: checkboxes
    $Grid.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new()) # row 2: log
    $Grid.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new()) # row 3: button

    # Label
    $ScanLabel = [System.Windows.Controls.TextBlock]::new()
    $ScanLabel.Text = "Scanning for installed bloatware..."
    $ScanLabel.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#888888")
    $ScanLabel.FontSize = 12
    $ScanLabel.Margin = [System.Windows.Thickness]::new(16,8,16,4)
    [System.Windows.Controls.Grid]::SetRow($ScanLabel, 0)
    $Grid.Children.Add($ScanLabel) | Out-Null

    # ScrollViewer with StackPanel for checkboxes
    $Scroll = [System.Windows.Controls.ScrollViewer]::new()
    $Scroll.VerticalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
    $Scroll.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E1E1E")
    $Scroll.Margin = [System.Windows.Thickness]::new(16,0,16,8)
    $Stack = [System.Windows.Controls.StackPanel]::new()
    $Stack.Margin = [System.Windows.Thickness]::new(8)
    $Scroll.Content = $Stack
    [System.Windows.Controls.Grid]::SetRow($Scroll, 1)
    $Grid.Children.Add($Scroll) | Out-Null

    # Log panel
    $LogBox = New-LogPanel
    $LogBox.Height = 150
    $LogBox.Margin = [System.Windows.Thickness]::new(16,0,16,8)
    [System.Windows.Controls.Grid]::SetRow($LogBox, 2)
    $Grid.Children.Add($LogBox) | Out-Null

    # Run button
    $RunBtn = [System.Windows.Controls.Button]::new()
    $RunBtn.Content = "Run Debloat"
    $RunBtn.Margin = [System.Windows.Thickness]::new(16,0,16,16)
    $RunBtn.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
    [System.Windows.Controls.Grid]::SetRow($RunBtn, 3)
    $Grid.Children.Add($RunBtn) | Out-Null

    # Populate checkboxes after window loads
    $Window.Add_Loaded({
        $InstalledItems = Get-InstalledDebloatItems -DebloatList $Config.debloat
        if ($InstalledItems.Count -eq 0) {
            $ScanLabel.Text = "No bloatware detected on this machine."
            $RunBtn.IsEnabled = $false
        } else {
            $ScanLabel.Text = "$($InstalledItems.Count) item(s) found. Untick anything you want to keep."
            foreach ($item in $InstalledItems) {
                $cb = [System.Windows.Controls.CheckBox]::new()
                $cb.Content   = $item.name
                $cb.IsChecked = $true
                $cb.Tag       = $item
                $cb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F0F0F0")
                $cb.FontSize  = 13
                $cb.Margin    = [System.Windows.Thickness]::new(0,4,0,4)
                $Stack.Children.Add($cb) | Out-Null
            }
        }
    })

    $RunBtn.Add_Click({
        $Selected = $Stack.Children | Where-Object { $_ -is [System.Windows.Controls.CheckBox] -and $_.IsChecked }
        if (-not $Selected) {
            Write-Log -LogBox $LogBox -Message "Nothing selected."
            return
        }

        $Work = {
            foreach ($cb in $Selected) {
                $item = $cb.Tag
                "Removing: $($item.name)..."
                try {
                    if ($item.type -eq "winget") {
                        & winget uninstall --id $item.id --silent --accept-source-agreements 2>&1
                    } elseif ($item.type -eq "appx") {
                        Get-AppxPackage -AllUsers -Name $item.id | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                        "Done: $($item.name)"
                    } elseif ($item.type -eq "both") {
                        & winget uninstall --id $item.id --silent --accept-source-agreements 2>&1
                        Get-AppxPackage -AllUsers -Name $item.id | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                        "Done: $($item.name)"
                    }
                } catch {
                    "Error removing $($item.name): $_"
                }
            }
            "--- Debloat complete ---"
        }

        $OnComplete = {
            $result = [System.Windows.MessageBox]::Show(
                "Debloat complete.`n`nSome changes require a restart to take effect.`n`nRestart now?",
                "VITS Windows Debloater",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Question
            )
            if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                Restart-Computer -Force
            }
        }

        Invoke-InRunspace -LogBox $LogBox -Button $RunBtn -Work $Work -OnComplete $OnComplete
    })
}
```

- [ ] **Step 3: Commit**

```bash
git add GUI.ps1
git commit -m "feat: implement Debloat tab with machine scan and removal"
```

---

### Task 6: Implement Build-InstallTab

**Files:**
- Modify: `GUI.ps1` (add before `Start-VITSDebloater`)

- [ ] **Step 1: Add Build-InstallTab function**

```powershell
function Build-InstallTab {
    param($Grid, $Config, $Window)

    $Grid.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new()) # row 0: label
    $rd1 = [System.Windows.Controls.RowDefinition]::new(); $rd1.Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $Grid.RowDefinitions.Add($rd1) # row 1: checkboxes
    $Grid.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new()) # row 2: log
    $Grid.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new()) # row 3: button

    $Label = [System.Windows.Controls.TextBlock]::new()
    $Label.Text = "Tick the apps you want to install. All install silently via winget."
    $Label.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#888888")
    $Label.FontSize = 12
    $Label.Margin = [System.Windows.Thickness]::new(16,8,16,4)
    [System.Windows.Controls.Grid]::SetRow($Label, 0)
    $Grid.Children.Add($Label) | Out-Null

    $Scroll = [System.Windows.Controls.ScrollViewer]::new()
    $Scroll.VerticalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
    $Scroll.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E1E1E")
    $Scroll.Margin = [System.Windows.Thickness]::new(16,0,16,8)
    $Stack = [System.Windows.Controls.StackPanel]::new()
    $Stack.Margin = [System.Windows.Thickness]::new(8)
    $Scroll.Content = $Stack
    [System.Windows.Controls.Grid]::SetRow($Scroll, 1)
    $Grid.Children.Add($Scroll) | Out-Null

    foreach ($app in $Config.install) {
        $cb = [System.Windows.Controls.CheckBox]::new()
        $cb.Content   = $app.name
        $cb.IsChecked = $false
        $cb.Tag       = $app.id
        $cb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F0F0F0")
        $cb.FontSize  = 13
        $cb.Margin    = [System.Windows.Thickness]::new(0,4,0,4)
        $Stack.Children.Add($cb) | Out-Null
    }

    $LogBox = New-LogPanel
    $LogBox.Height = 150
    $LogBox.Margin = [System.Windows.Thickness]::new(16,0,16,8)
    [System.Windows.Controls.Grid]::SetRow($LogBox, 2)
    $Grid.Children.Add($LogBox) | Out-Null

    $RunBtn = [System.Windows.Controls.Button]::new()
    $RunBtn.Content = "Run Install"
    $RunBtn.Margin = [System.Windows.Thickness]::new(16,0,16,16)
    $RunBtn.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
    [System.Windows.Controls.Grid]::SetRow($RunBtn, 3)
    $Grid.Children.Add($RunBtn) | Out-Null

    $RunBtn.Add_Click({
        $Selected = $Stack.Children | Where-Object { $_ -is [System.Windows.Controls.CheckBox] -and $_.IsChecked }
        if (-not $Selected) {
            Write-Log -LogBox $LogBox -Message "Nothing selected."
            return
        }

        $Work = {
            foreach ($cb in $Selected) {
                $id = $cb.Tag
                "Installing: $($cb.Content)..."
                & winget install --id $id --silent --accept-package-agreements --accept-source-agreements 2>&1
                "Done: $($cb.Content)"
            }
            "--- Install complete ---"
        }

        Invoke-InRunspace -LogBox $LogBox -Button $RunBtn -Work $Work
    })
}
```

- [ ] **Step 2: Commit**

```bash
git add GUI.ps1
git commit -m "feat: implement Install tab"
```

---

### Task 7: Implement Build-UpdatesTab

**Files:**
- Modify: `GUI.ps1` (add before `Start-VITSDebloater`)

- [ ] **Step 1: Add Build-UpdatesTab function**

```powershell
function Build-UpdatesTab {
    param($Grid, $Window)

    $Grid.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new()) # row 0: label
    $rd1 = [System.Windows.Controls.RowDefinition]::new(); $rd1.Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $Grid.RowDefinitions.Add($rd1) # row 1: log
    $Grid.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new()) # row 2: button

    $Label = [System.Windows.Controls.TextBlock]::new()
    $Label.Text = "Runs 'winget upgrade --all' to update every installed application silently."
    $Label.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#888888")
    $Label.FontSize = 12
    $Label.Margin = [System.Windows.Thickness]::new(16,8,16,4)
    [System.Windows.Controls.Grid]::SetRow($Label, 0)
    $Grid.Children.Add($Label) | Out-Null

    $LogBox = New-LogPanel
    $LogBox.Margin = [System.Windows.Thickness]::new(16,8,16,8)
    [System.Windows.Controls.Grid]::SetRow($LogBox, 1)
    $Grid.Children.Add($LogBox) | Out-Null

    $RunBtn = [System.Windows.Controls.Button]::new()
    $RunBtn.Content = "Run Winget Updates"
    $RunBtn.Margin = [System.Windows.Thickness]::new(16,0,16,16)
    $RunBtn.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
    [System.Windows.Controls.Grid]::SetRow($RunBtn, 2)
    $Grid.Children.Add($RunBtn) | Out-Null

    $RunBtn.Add_Click({
        $Work = {
            "Running winget upgrade --all ..."
            & winget upgrade --all --silent --accept-package-agreements --accept-source-agreements 2>&1
            "--- Updates complete ---"
        }
        Invoke-InRunspace -LogBox $LogBox -Button $RunBtn -Work $Work
    })
}
```

- [ ] **Step 2: Commit**

```bash
git add GUI.ps1
git commit -m "feat: implement Updates tab"
```

---

### Task 8: Implement Build-TweaksTab

**Files:**
- Modify: `GUI.ps1` (add before `Start-VITSDebloater`)

- [ ] **Step 1: Add Apply-Tweak helper**

Add before `Build-TweaksTab`:

```powershell
function Invoke-Tweak {
    param([string]$Key)
    switch ($Key) {
        "DisableFastStartup" {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0 -Type DWord -Force
            "Fast Startup disabled."
        }
        "DisableTips" {
            $path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
            $props = @("SubscribedContent-338388Enabled","SubscribedContent-338389Enabled","SubscribedContent-353694Enabled","SubscribedContent-353696Enabled","SoftLandingEnabled","SystemPaneSuggestionsEnabled")
            foreach ($p in $props) {
                Set-ItemProperty -Path $path -Name $p -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            }
            "Windows tips and suggestions disabled."
        }
        "DisableTelemetry" {
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            $tasks = @("Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser","Microsoft\Windows\Application Experience\ProgramDataUpdater","Microsoft\Windows\Autochk\Proxy","Microsoft\Windows\Customer Experience Improvement Program\Consolidator","Microsoft\Windows\Customer Experience Improvement Program\UsbCeip","Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector")
            foreach ($t in $tasks) {
                Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null
            }
            "Telemetry disabled."
        }
        "DisableBingSearch" {
            $path = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
            if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
            Set-ItemProperty -Path $path -Name "DisableSearchBoxSuggestions" -Value 1 -Type DWord -Force
            "Bing search in Start Menu disabled."
        }
        "HighPerformance" {
            & powercfg /setactive SCHEME_MIN 2>&1
            "Power plan set to High Performance."
        }
        "ChromeDefault" {
            Start-Process "ms-settings:defaultapps"
            "Windows Default Apps opened. Set Google Chrome as your default browser in that window."
        }
    }
}
```

- [ ] **Step 2: Add Build-TweaksTab function**

```powershell
function Build-TweaksTab {
    param($Grid, $Config, $Window)

    $Grid.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new()) # row 0: label
    $rd1 = [System.Windows.Controls.RowDefinition]::new(); $rd1.Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $Grid.RowDefinitions.Add($rd1) # row 1: checkboxes
    $Grid.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new()) # row 2: log
    $Grid.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new()) # row 3: button

    $Label = [System.Windows.Controls.TextBlock]::new()
    $Label.Text = "Select tweaks to apply. All unticked by default."
    $Label.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#888888")
    $Label.FontSize = 12
    $Label.Margin = [System.Windows.Thickness]::new(16,8,16,4)
    [System.Windows.Controls.Grid]::SetRow($Label, 0)
    $Grid.Children.Add($Label) | Out-Null

    $Scroll = [System.Windows.Controls.ScrollViewer]::new()
    $Scroll.VerticalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
    $Scroll.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E1E1E")
    $Scroll.Margin = [System.Windows.Thickness]::new(16,0,16,8)
    $Stack = [System.Windows.Controls.StackPanel]::new()
    $Stack.Margin = [System.Windows.Thickness]::new(8)
    $Scroll.Content = $Stack
    [System.Windows.Controls.Grid]::SetRow($Scroll, 1)
    $Grid.Children.Add($Scroll) | Out-Null

    foreach ($tweak in $Config.tweaks) {
        $panel = [System.Windows.Controls.StackPanel]::new()
        $panel.Margin = [System.Windows.Thickness]::new(0,4,0,4)

        $cb = [System.Windows.Controls.CheckBox]::new()
        $cb.Content   = $tweak.name
        $cb.IsChecked = $false
        $cb.Tag       = $tweak.key
        $cb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F0F0F0")
        $cb.FontSize  = 13

        $desc = [System.Windows.Controls.TextBlock]::new()
        $desc.Text = $tweak.description
        $desc.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#888888")
        $desc.FontSize = 11
        $desc.Margin = [System.Windows.Thickness]::new(20,2,0,0)
        $desc.TextWrapping = [System.Windows.TextWrapping]::Wrap

        $panel.Children.Add($cb)   | Out-Null
        $panel.Children.Add($desc) | Out-Null
        $Stack.Children.Add($panel) | Out-Null
    }

    $LogBox = New-LogPanel
    $LogBox.Height = 120
    $LogBox.Margin = [System.Windows.Thickness]::new(16,0,16,8)
    [System.Windows.Controls.Grid]::SetRow($LogBox, 2)
    $Grid.Children.Add($LogBox) | Out-Null

    $RunBtn = [System.Windows.Controls.Button]::new()
    $RunBtn.Content = "Apply Tweaks"
    $RunBtn.Margin = [System.Windows.Thickness]::new(16,0,16,16)
    $RunBtn.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
    [System.Windows.Controls.Grid]::SetRow($RunBtn, 3)
    $Grid.Children.Add($RunBtn) | Out-Null

    $RunBtn.Add_Click({
        $Selected = @()
        foreach ($panel in $Stack.Children) {
            $cb = $panel.Children | Where-Object { $_ -is [System.Windows.Controls.CheckBox] }
            if ($cb -and $cb.IsChecked) { $Selected += $cb.Tag }
        }
        if (-not $Selected) {
            Write-Log -LogBox $LogBox -Message "Nothing selected."
            return
        }

        $Work = {
            foreach ($key in $Selected) {
                Invoke-Tweak -Key $key | ForEach-Object { $_ }
            }
            "--- Tweaks complete ---"
        }

        Invoke-InRunspace -LogBox $LogBox -Button $RunBtn -Work $Work
    })
}
```

- [ ] **Step 3: Commit**

```bash
git add GUI.ps1
git commit -m "feat: implement Tweaks tab with all system tweaks"
```

---

### Task 9: Implement Build-AboutTab

**Files:**
- Modify: `GUI.ps1` (add before `Start-VITSDebloater`)

- [ ] **Step 1: Add Build-AboutTab function**

```powershell
function Build-AboutTab {
    param($Grid, $Config)

    $Panel = [System.Windows.Controls.StackPanel]::new()
    $Panel.Margin = [System.Windows.Thickness]::new(40,40,40,40)
    $Panel.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $Panel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center

    $Title = [System.Windows.Controls.TextBlock]::new()
    $Title.Text = "VITS Windows Debloater"
    $Title.FontSize = 26
    $Title.FontWeight = [System.Windows.FontWeights]::Bold
    $Title.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F0F0F0")
    $Title.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $Title.Margin = [System.Windows.Thickness]::new(0,0,0,8)

    $Version = [System.Windows.Controls.TextBlock]::new()
    $Version.Text = "Version $($Config.version)"
    $Version.FontSize = 13
    $Version.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#888888")
    $Version.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $Version.Margin = [System.Windows.Thickness]::new(0,0,0,32)

    $Credit = [System.Windows.Controls.TextBlock]::new()
    $Credit.Text = "VITS | Ravi Singh"
    $Credit.FontSize = 15
    $Credit.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0078D4")
    $Credit.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $Credit.Margin = [System.Windows.Thickness]::new(0,0,0,16)

    $RepoLabel = [System.Windows.Controls.TextBlock]::new()
    $RepoLabel.Text = "Source code:"
    $RepoLabel.FontSize = 12
    $RepoLabel.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#888888")
    $RepoLabel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center

    $RepoLink = [System.Windows.Documents.Hyperlink]::new()
    $RepoLink.NavigateUri = [Uri]::new("https://github.com/VITS-Ltd/Windows-Debloater")
    $RepoLink.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0078D4")
    $RepoLink.Add_RequestNavigate({
        Start-Process $_.Uri.AbsoluteUri
        $_.Handled = $true
    })
    $RepoLink.Inlines.Add("https://github.com/VITS-Ltd/Windows-Debloater")

    $RepoText = [System.Windows.Controls.TextBlock]::new()
    $RepoText.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $RepoText.Margin = [System.Windows.Thickness]::new(0,4,0,0)
    $RepoText.Inlines.Add($RepoLink)

    $Panel.Children.Add($Title)     | Out-Null
    $Panel.Children.Add($Version)   | Out-Null
    $Panel.Children.Add($Credit)    | Out-Null
    $Panel.Children.Add($RepoLabel) | Out-Null
    $Panel.Children.Add($RepoText)  | Out-Null

    $Grid.Children.Add($Panel) | Out-Null
}
```

- [ ] **Step 2: Commit**

```bash
git add GUI.ps1
git commit -m "feat: implement About tab"
```

---

### Task 10: Push to GitHub and verify one-liner works

**Files:** none

- [ ] **Step 1: Push all commits**

```bash
git push -u origin main
```

- [ ] **Step 2: Verify raw URLs are accessible**

Open these in a browser and confirm the raw file content loads:
- `https://raw.githubusercontent.com/VITS-Ltd/Windows-Debloater/main/Run.ps1`
- `https://raw.githubusercontent.com/VITS-Ltd/Windows-Debloater/main/GUI.ps1`
- `https://raw.githubusercontent.com/VITS-Ltd/Windows-Debloater/main/config.json`

- [ ] **Step 3: Test the one-liner on a Windows 11 machine**

Open PowerShell (non-admin first to test the elevation prompt):
```powershell
irm https://raw.githubusercontent.com/VITS-Ltd/Windows-Debloater/main/Run.ps1 | iex
```

Expected: elevation prompt appears. Accept. GUI opens with correct hostname/username in header.

- [ ] **Step 4: Smoke test each tab**

- Debloat: verify only installed items appear, pre-ticked
- Install: verify all apps listed, unticked
- Updates: click button, verify winget output streams to log
- Tweaks: tick one low-risk tweak (e.g. Disable Bing Search), apply, verify it works
- About: verify link opens GitHub repo in browser
