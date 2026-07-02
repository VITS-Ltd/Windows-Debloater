# VITS Windows Debloater

A PowerShell GUI tool for quickly setting up new Windows machines for VITS customers. Removes pre-installed bloatware, installs standard apps, runs updates, and applies system tweaks — all from a single one-liner.

**Built by VITS | Ravi Singh**

---

## Quick Start

Open PowerShell **as Administrator** and run:

```powershell
irm https://raw.githubusercontent.com/VITS-Ltd/Windows-Debloater/main/Run.ps1 | iex
```

If not running as admin, the tool will prompt you to relaunch elevated automatically.

---

## What It Does

### Debloat
Scans the machine for installed bloatware and shows only what's actually present. All items are pre-ticked — untick anything you want to keep, then click **Run Debloat**.

Removes:
- Lenovo OEM apps (AI Now, Smart Meeting, Speech)
- Xbox apps and Game Bar
- Microsoft Cortana
- Clipchamp, Tips, Weather, News, Maps, Solitaire Collection

### Install
Tick the apps you want to install. All install silently via winget.

Available apps:
- Google Chrome, Mozilla Firefox
- 7-Zip, Notepad++, VLC
- Adobe Acrobat Reader
- Microsoft 365, Microsoft Teams
- Bitwarden, LastPass
- Dropbox, Everything (Void Tools)
- PowerShell (latest), Python 3, Git for Windows
- Signal, WhatsApp, Webex (Cisco)
- Windows Terminal, VS Code
- Power BI Desktop

### Updates
Runs `winget upgrade --all` to silently update every installed application on the machine.

### Tweaks
Optional system configuration tweaks (all unticked by default):
- Disable Fast Startup
- Disable Windows Tips & Suggestions
- Disable Telemetry & Data Collection
- Disable Bing Search in Start Menu
- Set Power Plan to High Performance
- Set Chrome as Default Browser (opens Windows Default Apps settings)

---

## Adding or Removing Apps

Edit `config.json` only. No code changes needed.

To add a debloat entry:
```json
{ "name": "App Display Name", "type": "appx", "id": "Package.AppxName" }
```

Types: `appx` (Store apps), `winget` (winget packages), `both` (try both methods).

To add an install entry:
```json
{ "name": "App Display Name", "id": "Winget.PackageId" }
```

Find winget IDs with: `winget search <appname>`

---

## Requirements

- Windows 11 (winget pre-installed)
- PowerShell 5.1+ (built in)
- Internet connection (downloads latest scripts from GitHub on each run)

---

## How It Works

1. `Run.ps1` — entry point downloaded by the one-liner. Checks elevation, downloads `GUI.ps1` and `config.json` from GitHub, launches the GUI.
2. `GUI.ps1` — WPF dark-mode GUI. Reads config, scans the machine, renders all 5 tabs.
3. `config.json` — the only file to edit when maintaining app lists.

Scripts are always pulled fresh from GitHub, so updating the tool is as simple as pushing changes to this repo.
