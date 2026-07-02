#Requires -Version 5.1
Set-ExecutionPolicy Bypass -Scope Process -Force

$BaseUrl = "https://raw.githubusercontent.com/VITS-Ltd/Windows-Debloater/main"
$TempDir = "$env:TEMP\VITSDebloater"

function Test-Admin {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
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
