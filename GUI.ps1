Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# ── Helpers ──────────────────────────────────────────────────────────────────

function New-LogPanel {
    $tb = [System.Windows.Controls.TextBox]::new()
    $tb.IsReadOnly = $true
    $tb.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $tb.VerticalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
    $tb.Background  = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1A1A1A")
    $tb.Foreground  = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#B0FFB0")
    $tb.FontFamily  = [System.Windows.Media.FontFamily]::new("Consolas")
    $tb.FontSize    = 12
    $tb.BorderThickness = [System.Windows.Thickness]::new(1)
    $tb.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#3E3E3E")
    $tb.Padding     = [System.Windows.Thickness]::new(8)
    return $tb
}

function Write-Log {
    param($LogBox, [string]$Message)
    $LogBox.Dispatcher.Invoke([Action]{
        $LogBox.AppendText("$Message`n")
        $LogBox.ScrollToEnd()
    })
}

function Invoke-InRunspace {
    param(
        [System.Windows.Controls.TextBox]$LogBox,
        [System.Windows.Controls.Button]$Button,
        [scriptblock]$Work,
        $WorkArgs = @(),
        [scriptblock]$OnComplete = {}
    )

    $Button.IsEnabled = $false
    $LogBox.Clear()

    $Runspace = [runspacefactory]::CreateRunspace()
    $Runspace.ApartmentState = [System.Threading.ApartmentState]::STA
    $Runspace.ThreadOptions  = [System.Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
    $Runspace.Open()

    $PS = [powershell]::Create()
    $PS.Runspace = $Runspace

    $PS.AddScript({
        param($Work, $WorkArgs, $LogBox)
        $results = & $Work @WorkArgs
        foreach ($line in $results) {
            if ($null -ne $line) {
                $LogBox.Dispatcher.Invoke([Action]{
                    $LogBox.AppendText("$line`n")
                    $LogBox.ScrollToEnd()
                })
            }
        }
    }).AddArgument($Work).AddArgument($WorkArgs).AddArgument($LogBox) | Out-Null

    $Handle = $PS.BeginInvoke()

    $Timer = [System.Windows.Threading.DispatcherTimer]::new()
    $Timer.Interval = [TimeSpan]::FromMilliseconds(300)
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

# ── Machine scan for debloat ──────────────────────────────────────────────────

function Get-InstalledDebloatItems {
    param($DebloatList)

    $WingetOutput = (& winget list 2>&1) | Out-String
    $AppxPackages  = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
                     Select-Object -ExpandProperty Name

    $installed = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $DebloatList) {
        $found = $false
        switch ($item.type) {
            "winget" { if ($WingetOutput -match [regex]::Escape($item.id)) { $found = $true } }
            "appx"   { if ($AppxPackages -contains $item.id)               { $found = $true } }
            "both"   {
                if (($WingetOutput -match [regex]::Escape($item.id)) -or
                    ($AppxPackages -contains $item.id)) { $found = $true }
            }
        }
        if ($found) { $installed.Add($item) }
    }
    return $installed
}

# ── Tab builders ──────────────────────────────────────────────────────────────

function Build-DebloatTab {
    param($Grid, $Config, $Window)

    $r0 = [System.Windows.Controls.RowDefinition]::new(); $r0.Height = [System.Windows.GridLength]::Auto
    $r1 = [System.Windows.Controls.RowDefinition]::new(); $r1.Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $r2 = [System.Windows.Controls.RowDefinition]::new(); $r2.Height = [System.Windows.GridLength]::new(150, [System.Windows.GridUnitType]::Pixel)
    $r3 = [System.Windows.Controls.RowDefinition]::new(); $r3.Height = [System.Windows.GridLength]::Auto
    $Grid.RowDefinitions.Add($r0)
    $Grid.RowDefinitions.Add($r1)
    $Grid.RowDefinitions.Add($r2)
    $Grid.RowDefinitions.Add($r3)

    $ScanLabel = [System.Windows.Controls.TextBlock]::new()
    $ScanLabel.Text       = "Scanning for installed bloatware..."
    $ScanLabel.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#888888")
    $ScanLabel.FontSize   = 12
    $ScanLabel.Margin     = [System.Windows.Thickness]::new(16, 10, 16, 4)
    [System.Windows.Controls.Grid]::SetRow($ScanLabel, 0)
    $Grid.Children.Add($ScanLabel) | Out-Null

    $Scroll = [System.Windows.Controls.ScrollViewer]::new()
    $Scroll.VerticalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
    $Scroll.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E1E1E")
    $Scroll.Margin     = [System.Windows.Thickness]::new(16, 0, 16, 8)
    $Stack = [System.Windows.Controls.StackPanel]::new()
    $Stack.Margin = [System.Windows.Thickness]::new(8)
    $Scroll.Content = $Stack
    [System.Windows.Controls.Grid]::SetRow($Scroll, 1)
    $Grid.Children.Add($Scroll) | Out-Null

    $LogBox = New-LogPanel
    $LogBox.Margin = [System.Windows.Thickness]::new(16, 0, 16, 8)
    [System.Windows.Controls.Grid]::SetRow($LogBox, 2)
    $Grid.Children.Add($LogBox) | Out-Null

    $RunBtn = [System.Windows.Controls.Button]::new()
    $RunBtn.Content             = "Run Debloat"
    $RunBtn.Margin              = [System.Windows.Thickness]::new(16, 0, 16, 16)
    $RunBtn.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
    $RunBtn.IsEnabled           = $false
    [System.Windows.Controls.Grid]::SetRow($RunBtn, 3)
    $Grid.Children.Add($RunBtn) | Out-Null

    # Capture UI elements for use inside the runspace dispatcher
    $script:_ScanLabel = $ScanLabel
    $script:_RunBtn    = $RunBtn
    $script:_Stack     = $Stack

    $Window.Add_ContentRendered({
        $DebloatList = $Config.debloat

        $RS = [runspacefactory]::CreateRunspace()
        $RS.ApartmentState = [System.Threading.ApartmentState]::STA
        $RS.ThreadOptions  = [System.Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
        $RS.Open()

        $PS = [powershell]::Create()
        $PS.Runspace = $RS

        $PS.AddScript({
            param($DebloatList, $ScanLabel, $RunBtn, $Stack)

            $WingetOutput = (& winget list 2>&1) | Out-String
            $AppxPackages  = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
                             Select-Object -ExpandProperty Name

            $installed = [System.Collections.Generic.List[object]]::new()
            foreach ($item in $DebloatList) {
                $found = $false
                switch ($item.type) {
                    "winget" { if ($WingetOutput -match [regex]::Escape($item.id)) { $found = $true } }
                    "appx"   { if ($AppxPackages -contains $item.id)               { $found = $true } }
                    "both"   {
                        if (($WingetOutput -match [regex]::Escape($item.id)) -or
                            ($AppxPackages -contains $item.id)) { $found = $true }
                    }
                }
                if ($found) { $installed.Add($item) }
            }

            $ScanLabel.Dispatcher.Invoke([Action]{
                if ($installed.Count -eq 0) {
                    $ScanLabel.Text = "No bloatware detected on this machine."
                } else {
                    $ScanLabel.Text   = "$($installed.Count) item(s) found. Untick anything you want to keep."
                    $RunBtn.IsEnabled = $true
                    foreach ($item in $installed) {
                        $cb           = [System.Windows.Controls.CheckBox]::new()
                        $cb.Content   = $item.name
                        $cb.IsChecked = $true
                        $cb.Tag       = $item
                        $cb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F0F0F0")
                        $cb.FontSize  = 13
                        $cb.Margin    = [System.Windows.Thickness]::new(0, 4, 0, 4)
                        $Stack.Children.Add($cb) | Out-Null
                    }
                }
            })

        }).AddArgument($DebloatList).AddArgument($script:_ScanLabel).AddArgument($script:_RunBtn).AddArgument($script:_Stack) | Out-Null

        $PS.BeginInvoke() | Out-Null
    })

    $RunBtn.Add_Click({
        $SelectedItems = @(
            $Stack.Children |
            Where-Object { $_ -is [System.Windows.Controls.CheckBox] -and $_.IsChecked } |
            ForEach-Object { $_.Tag }
        )
        if ($SelectedItems.Count -eq 0) {
            Write-Log -LogBox $LogBox -Message "Nothing selected."
            return
        }

        $Work = {
            param($Items)
            foreach ($item in $Items) {
                "Removing: $($item.name)..."
                try {
                    if ($item.type -eq "winget") {
                        & winget uninstall --id $item.id --silent --accept-source-agreements 2>&1
                    } elseif ($item.type -eq "appx") {
                        Get-AppxPackage -AllUsers -Name $item.id -ErrorAction SilentlyContinue |
                            Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                            Where-Object { $_.PackageName -like "*$($item.id)*" } |
                            Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
                        "  Done."
                    } elseif ($item.type -eq "both") {
                        & winget uninstall --id $item.id --silent --accept-source-agreements 2>&1
                        Get-AppxPackage -AllUsers -Name $item.id -ErrorAction SilentlyContinue |
                            Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                            Where-Object { $_.PackageName -like "*$($item.id)*" } |
                            Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
                        "  Done."
                    }
                } catch {
                    "  Error: $_"
                }
            }
            "--- Debloat complete ---"
        }

        $OnComplete = {
            $r = [System.Windows.MessageBox]::Show(
                "Debloat complete.`n`nSome changes require a restart to take effect.`n`nRestart now?",
                "VITS Windows Debloater",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Question
            )
            if ($r -eq [System.Windows.MessageBoxResult]::Yes) { Restart-Computer -Force }
        }

        Invoke-InRunspace -LogBox $LogBox -Button $RunBtn -Work $Work -WorkArgs @(,$SelectedItems) -OnComplete $OnComplete
    })
}

function Build-InstallTab {
    param($Grid, $Config, $Window)

    $r0 = [System.Windows.Controls.RowDefinition]::new(); $r0.Height = [System.Windows.GridLength]::Auto
    $r1 = [System.Windows.Controls.RowDefinition]::new(); $r1.Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $r2 = [System.Windows.Controls.RowDefinition]::new(); $r2.Height = [System.Windows.GridLength]::new(150, [System.Windows.GridUnitType]::Pixel)
    $r3 = [System.Windows.Controls.RowDefinition]::new(); $r3.Height = [System.Windows.GridLength]::Auto
    $Grid.RowDefinitions.Add($r0)
    $Grid.RowDefinitions.Add($r1)
    $Grid.RowDefinitions.Add($r2)
    $Grid.RowDefinitions.Add($r3)

    $Label = [System.Windows.Controls.TextBlock]::new()
    $Label.Text       = "Tick the apps you want to install. All install silently via winget."
    $Label.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#888888")
    $Label.FontSize   = 12
    $Label.Margin     = [System.Windows.Thickness]::new(16, 10, 16, 4)
    [System.Windows.Controls.Grid]::SetRow($Label, 0)
    $Grid.Children.Add($Label) | Out-Null

    $Scroll = [System.Windows.Controls.ScrollViewer]::new()
    $Scroll.VerticalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
    $Scroll.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E1E1E")
    $Scroll.Margin     = [System.Windows.Thickness]::new(16, 0, 16, 8)
    $Stack = [System.Windows.Controls.StackPanel]::new()
    $Stack.Margin = [System.Windows.Thickness]::new(8)
    $Scroll.Content = $Stack
    [System.Windows.Controls.Grid]::SetRow($Scroll, 1)
    $Grid.Children.Add($Scroll) | Out-Null

    foreach ($app in $Config.install) {
        $cb           = [System.Windows.Controls.CheckBox]::new()
        $cb.Content   = $app.name
        $cb.IsChecked = $false
        $cb.Tag       = $app.id
        $cb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F0F0F0")
        $cb.FontSize  = 13
        $cb.Margin    = [System.Windows.Thickness]::new(0, 4, 0, 4)
        $Stack.Children.Add($cb) | Out-Null
    }

    $LogBox = New-LogPanel
    $LogBox.Margin = [System.Windows.Thickness]::new(16, 0, 16, 8)
    [System.Windows.Controls.Grid]::SetRow($LogBox, 2)
    $Grid.Children.Add($LogBox) | Out-Null

    $RunBtn = [System.Windows.Controls.Button]::new()
    $RunBtn.Content             = "Run Install"
    $RunBtn.Margin              = [System.Windows.Thickness]::new(16, 0, 16, 16)
    $RunBtn.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
    [System.Windows.Controls.Grid]::SetRow($RunBtn, 3)
    $Grid.Children.Add($RunBtn) | Out-Null

    $RunBtn.Add_Click({
        $SelectedApps = @(
            $Stack.Children |
            Where-Object { $_ -is [System.Windows.Controls.CheckBox] -and $_.IsChecked } |
            ForEach-Object { [PSCustomObject]@{ Name = $_.Content; Id = $_.Tag } }
        )
        if ($SelectedApps.Count -eq 0) {
            Write-Log -LogBox $LogBox -Message "Nothing selected."
            return
        }

        $Work = {
            param($Apps)
            foreach ($app in $Apps) {
                "Installing: $($app.Name)..."
                & winget install --id $app.Id --silent --accept-package-agreements --accept-source-agreements 2>&1
                "  Done: $($app.Name)"
            }
            "--- Install complete ---"
        }

        Invoke-InRunspace -LogBox $LogBox -Button $RunBtn -Work $Work -WorkArgs @(,$SelectedApps)
    })
}

function Build-UpdatesTab {
    param($Grid, $Window)

    $r0 = [System.Windows.Controls.RowDefinition]::new(); $r0.Height = [System.Windows.GridLength]::Auto
    $r1 = [System.Windows.Controls.RowDefinition]::new(); $r1.Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $r2 = [System.Windows.Controls.RowDefinition]::new(); $r2.Height = [System.Windows.GridLength]::Auto
    $Grid.RowDefinitions.Add($r0)
    $Grid.RowDefinitions.Add($r1)
    $Grid.RowDefinitions.Add($r2)

    $Label = [System.Windows.Controls.TextBlock]::new()
    $Label.Text       = "Runs 'winget upgrade --all' to update every installed application silently."
    $Label.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#888888")
    $Label.FontSize   = 12
    $Label.Margin     = [System.Windows.Thickness]::new(16, 10, 16, 4)
    [System.Windows.Controls.Grid]::SetRow($Label, 0)
    $Grid.Children.Add($Label) | Out-Null

    $LogBox = New-LogPanel
    $LogBox.Margin = [System.Windows.Thickness]::new(16, 8, 16, 8)
    [System.Windows.Controls.Grid]::SetRow($LogBox, 1)
    $Grid.Children.Add($LogBox) | Out-Null

    $RunBtn = [System.Windows.Controls.Button]::new()
    $RunBtn.Content             = "Run Winget Updates"
    $RunBtn.Margin              = [System.Windows.Thickness]::new(16, 0, 16, 16)
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

function Invoke-Tweak {
    param([string]$Key)
    switch ($Key) {
        "DisableFastStartup" {
            $path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
            Set-ItemProperty -Path $path -Name "HiberbootEnabled" -Value 0 -Type DWord -Force
            "Fast Startup disabled."
        }
        "DisableTips" {
            $path  = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
            $props = @(
                "SubscribedContent-338388Enabled",
                "SubscribedContent-338389Enabled",
                "SubscribedContent-353694Enabled",
                "SubscribedContent-353696Enabled",
                "SoftLandingEnabled",
                "SystemPaneSuggestionsEnabled"
            )
            foreach ($p in $props) {
                Set-ItemProperty -Path $path -Name $p -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            }
            "Windows tips and suggestions disabled."
        }
        "DisableTelemetry" {
            $dcPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
            if (-not (Test-Path $dcPath)) { New-Item -Path $dcPath -Force | Out-Null }
            Set-ItemProperty -Path $dcPath -Name "AllowTelemetry" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            $tasks = @(
                "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
                "Microsoft\Windows\Application Experience\ProgramDataUpdater",
                "Microsoft\Windows\Autochk\Proxy",
                "Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
                "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
                "Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
            )
            foreach ($t in $tasks) {
                Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null
            }
            "Telemetry and data collection disabled."
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

function Build-TweaksTab {
    param($Grid, $Config, $Window)

    $r0 = [System.Windows.Controls.RowDefinition]::new(); $r0.Height = [System.Windows.GridLength]::Auto
    $r1 = [System.Windows.Controls.RowDefinition]::new(); $r1.Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $r2 = [System.Windows.Controls.RowDefinition]::new(); $r2.Height = [System.Windows.GridLength]::new(120, [System.Windows.GridUnitType]::Pixel)
    $r3 = [System.Windows.Controls.RowDefinition]::new(); $r3.Height = [System.Windows.GridLength]::Auto
    $Grid.RowDefinitions.Add($r0)
    $Grid.RowDefinitions.Add($r1)
    $Grid.RowDefinitions.Add($r2)
    $Grid.RowDefinitions.Add($r3)

    $Label = [System.Windows.Controls.TextBlock]::new()
    $Label.Text       = "Select tweaks to apply. All unticked by default."
    $Label.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#888888")
    $Label.FontSize   = 12
    $Label.Margin     = [System.Windows.Thickness]::new(16, 10, 16, 4)
    [System.Windows.Controls.Grid]::SetRow($Label, 0)
    $Grid.Children.Add($Label) | Out-Null

    $Scroll = [System.Windows.Controls.ScrollViewer]::new()
    $Scroll.VerticalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Auto
    $Scroll.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1E1E1E")
    $Scroll.Margin     = [System.Windows.Thickness]::new(16, 0, 16, 8)
    $Stack = [System.Windows.Controls.StackPanel]::new()
    $Stack.Margin = [System.Windows.Thickness]::new(8)
    $Scroll.Content = $Stack
    [System.Windows.Controls.Grid]::SetRow($Scroll, 1)
    $Grid.Children.Add($Scroll) | Out-Null

    foreach ($tweak in $Config.tweaks) {
        $panel        = [System.Windows.Controls.StackPanel]::new()
        $panel.Margin = [System.Windows.Thickness]::new(0, 4, 0, 8)

        $cb           = [System.Windows.Controls.CheckBox]::new()
        $cb.Content   = $tweak.name
        $cb.IsChecked = $false
        $cb.Tag       = $tweak.key
        $cb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F0F0F0")
        $cb.FontSize  = 13

        $desc              = [System.Windows.Controls.TextBlock]::new()
        $desc.Text         = $tweak.description
        $desc.Foreground   = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#888888")
        $desc.FontSize     = 11
        $desc.Margin       = [System.Windows.Thickness]::new(22, 2, 0, 0)
        $desc.TextWrapping = [System.Windows.TextWrapping]::Wrap

        $panel.Children.Add($cb)   | Out-Null
        $panel.Children.Add($desc) | Out-Null
        $Stack.Children.Add($panel) | Out-Null
    }

    $LogBox = New-LogPanel
    $LogBox.Margin = [System.Windows.Thickness]::new(16, 0, 16, 8)
    [System.Windows.Controls.Grid]::SetRow($LogBox, 2)
    $Grid.Children.Add($LogBox) | Out-Null

    $RunBtn = [System.Windows.Controls.Button]::new()
    $RunBtn.Content             = "Apply Tweaks"
    $RunBtn.Margin              = [System.Windows.Thickness]::new(16, 0, 16, 16)
    $RunBtn.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
    [System.Windows.Controls.Grid]::SetRow($RunBtn, 3)
    $Grid.Children.Add($RunBtn) | Out-Null

    $RunBtn.Add_Click({
        $SelectedKeys = @(
            $Stack.Children | ForEach-Object {
                $_.Children | Where-Object { $_ -is [System.Windows.Controls.CheckBox] -and $_.IsChecked }
            } | ForEach-Object { $_.Tag }
        )
        if ($SelectedKeys.Count -eq 0) {
            Write-Log -LogBox $LogBox -Message "Nothing selected."
            return
        }

        # ChromeDefault opens a UI window - handle on UI thread, exclude from runspace
        if ($SelectedKeys -contains "ChromeDefault") {
            Start-Process "ms-settings:defaultapps"
            Write-Log -LogBox $LogBox -Message "Windows Default Apps opened. Set Google Chrome as your default browser in that window."
            $SelectedKeys = $SelectedKeys | Where-Object { $_ -ne "ChromeDefault" }
        }

        if ($SelectedKeys.Count -gt 0) {
            $Work = {
                param($Keys)
                foreach ($key in $Keys) {
                    switch ($key) {
                        "DisableFastStartup" {
                            $path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
                            Set-ItemProperty -Path $path -Name "HiberbootEnabled" -Value 0 -Type DWord -Force
                            "Fast Startup disabled."
                        }
                        "DisableTips" {
                            $path  = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
                            $props = @(
                                "SubscribedContent-338388Enabled",
                                "SubscribedContent-338389Enabled",
                                "SubscribedContent-353694Enabled",
                                "SubscribedContent-353696Enabled",
                                "SoftLandingEnabled",
                                "SystemPaneSuggestionsEnabled"
                            )
                            foreach ($p in $props) {
                                Set-ItemProperty -Path $path -Name $p -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                            }
                            "Windows tips and suggestions disabled."
                        }
                        "DisableTelemetry" {
                            $dcPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
                            if (-not (Test-Path $dcPath)) { New-Item -Path $dcPath -Force | Out-Null }
                            Set-ItemProperty -Path $dcPath -Name "AllowTelemetry" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                            $tasks = @(
                                "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
                                "Microsoft\Windows\Application Experience\ProgramDataUpdater",
                                "Microsoft\Windows\Autochk\Proxy",
                                "Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
                                "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
                                "Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
                            )
                            foreach ($t in $tasks) {
                                Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null
                            }
                            "Telemetry and data collection disabled."
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
                    }
                }
                "--- Tweaks complete ---"
            }
            Invoke-InRunspace -LogBox $LogBox -Button $RunBtn -Work $Work -WorkArgs @(,$SelectedKeys)
        } else {
            $RunBtn.IsEnabled = $true
        }
    })
}

function Build-AboutTab {
    param($Grid, $Config)

    $Panel = [System.Windows.Controls.StackPanel]::new()
    $Panel.VerticalAlignment   = [System.Windows.VerticalAlignment]::Center
    $Panel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $Panel.Margin              = [System.Windows.Thickness]::new(40)

    $Title            = [System.Windows.Controls.TextBlock]::new()
    $Title.Text       = "VITS Windows Debloater"
    $Title.FontSize   = 28
    $Title.FontWeight = [System.Windows.FontWeights]::Bold
    $Title.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F0F0F0")
    $Title.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $Title.Margin     = [System.Windows.Thickness]::new(0, 0, 0, 8)

    $Version            = [System.Windows.Controls.TextBlock]::new()
    $Version.Text       = "Version $($Config.version)"
    $Version.FontSize   = 13
    $Version.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#888888")
    $Version.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $Version.Margin     = [System.Windows.Thickness]::new(0, 0, 0, 32)

    $Credit            = [System.Windows.Controls.TextBlock]::new()
    $Credit.Text       = "VITS | Ravi Singh"
    $Credit.FontSize   = 16
    $Credit.FontWeight = [System.Windows.FontWeights]::SemiBold
    $Credit.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0078D4")
    $Credit.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $Credit.Margin     = [System.Windows.Thickness]::new(0, 0, 0, 20)

    $RepoLabel            = [System.Windows.Controls.TextBlock]::new()
    $RepoLabel.Text       = "Source code"
    $RepoLabel.FontSize   = 12
    $RepoLabel.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#888888")
    $RepoLabel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center

    $RepoLink = [System.Windows.Documents.Hyperlink]::new()
    $RepoLink.NavigateUri = [Uri]::new("https://github.com/VITS-Ltd/Windows-Debloater")
    $RepoLink.Foreground  = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0078D4")
    $RepoLink.Add_RequestNavigate({
        Start-Process $_.Uri.AbsoluteUri
        $_.Handled = $true
    })
    $RepoLink.Inlines.Add("https://github.com/VITS-Ltd/Windows-Debloater")

    $RepoText = [System.Windows.Controls.TextBlock]::new()
    $RepoText.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $RepoText.Margin    = [System.Windows.Thickness]::new(0, 4, 0, 0)
    $RepoText.Inlines.Add($RepoLink)

    foreach ($child in @($Title, $Version, $Credit, $RepoLabel, $RepoText)) {
        $Panel.Children.Add($child) | Out-Null
    }
    $Grid.Children.Add($Panel) | Out-Null
}

# ── Main entry point ──────────────────────────────────────────────────────────

function Start-VITSDebloater {
    param([string]$ConfigPath)

    $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

    [xml]$Xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="VITS Windows Debloater"
    Height="720" Width="920"
    MinHeight="600" MinWidth="800"
    WindowStartupLocation="CenterScreen"
    Background="#1E1E1E">

    <Window.Resources>
        <Style TargetType="TabItem">
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Padding" Value="18,9"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TabItem">
                        <Border x:Name="TabBorder" Background="#2D2D2D" BorderThickness="0" Padding="18,9" Margin="0,0,2,0">
                            <TextBlock x:Name="TabText" Text="{TemplateBinding Header}" Foreground="#AAAAAA" FontSize="13" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="TabBorder" Property="Background" Value="#0078D4"/>
                                <Setter TargetName="TabText" Property="Foreground" Value="#FFFFFF"/>
                                <Setter TargetName="TabText" Property="FontWeight" Value="SemiBold"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="TabBorder" Property="Background" Value="#3A3A3A"/>
                                <Setter TargetName="TabText" Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#0078D4"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="22,9"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#106EBE"/>
                </Trigger>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Background" Value="#3E3E3E"/>
                    <Setter Property="Foreground" Value="#666666"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#F0F0F0"/>
            <Setter Property="FontSize" Value="13"/>
        </Style>
    </Window.Resources>

    <DockPanel>
        <Border DockPanel.Dock="Top" Background="#2D2D2D" Padding="20,14">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0">
                    <TextBlock Text="VITS Windows Debloater" FontSize="20" FontWeight="Bold" Foreground="#F0F0F0"/>
                    <TextBlock x:Name="MachineInfoText" FontSize="12" Foreground="#666666" Margin="0,3,0,0"/>
                </StackPanel>
                <TextBlock Grid.Column="1" Text="VITS" FontSize="24" FontWeight="Bold"
                           Foreground="#0078D4" VerticalAlignment="Center"/>
            </Grid>
        </Border>

        <TabControl x:Name="MainTabControl" Background="#1E1E1E" BorderThickness="0" Padding="0"
                    TabStripPlacement="Top">
            <TabItem Header="Debloat">
                <Grid x:Name="DebloatGrid" Background="#1E1E1E"/>
            </TabItem>
            <TabItem Header="Install">
                <Grid x:Name="InstallGrid" Background="#1E1E1E"/>
            </TabItem>
            <TabItem Header="Updates">
                <Grid x:Name="UpdatesGrid" Background="#1E1E1E"/>
            </TabItem>
            <TabItem Header="Tweaks">
                <Grid x:Name="TweaksGrid" Background="#1E1E1E"/>
            </TabItem>
            <TabItem Header="About">
                <Grid x:Name="AboutGrid" Background="#1E1E1E"/>
            </TabItem>
        </TabControl>
    </DockPanel>
</Window>
"@

    $Reader = [System.Xml.XmlNodeReader]::new($Xaml)
    $Window = [Windows.Markup.XamlReader]::Load($Reader)

    $Window.FindName("MachineInfoText").Text = "Host: $env:COMPUTERNAME   |   User: $env:USERNAME"

    Build-DebloatTab  -Grid $Window.FindName("DebloatGrid")  -Config $Config -Window $Window
    Build-InstallTab  -Grid $Window.FindName("InstallGrid")  -Config $Config -Window $Window
    Build-UpdatesTab  -Grid $Window.FindName("UpdatesGrid")  -Window $Window
    Build-TweaksTab   -Grid $Window.FindName("TweaksGrid")   -Config $Config -Window $Window
    Build-AboutTab    -Grid $Window.FindName("AboutGrid")     -Config $Config

    $Window.ShowDialog() | Out-Null
}
