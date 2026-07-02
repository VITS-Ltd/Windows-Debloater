# VITS Windows Debloater - Design Spec

**Date:** 2026-07-02  
**Author:** VITS IT  
**Status:** Approved

---

## Purpose

A PowerShell-based GUI tool for VITS IT technicians to quickly debloat and configure new Windows machines (primarily Lenovo). Launched via a single one-liner, no pre-installation required.

**One-liner:**
```powershell
irm https://raw.githubusercontent.com/VITS-Ltd/Windows-Debloater/main/Run.ps1 | iex
```

---

## Files

| File | Purpose |
|---|---|
| `Run.ps1` | Entry point. Handles elevation, execution policy, downloads GUI.ps1 and config.json, launches GUI |
| `GUI.ps1` | WPF GUI. Reads config.json, scans machine, renders interface |
| `config.json` | App lists with winget IDs and AppxPackage names. Edit this to add/remove apps |

---

## Run.ps1 Behaviour

1. **Execution policy:** Bypass automatically and silently (`Set-ExecutionPolicy Bypass -Scope Process -Force`)
2. **Elevation check:** Detect if not running as admin. If not, show a message box: "This tool requires administrator rights. Relaunch as administrator now?" Yes = relaunch elevated via `Start-Process powershell -Verb RunAs`. No = exit cleanly.
3. **Download:** Fetch latest `GUI.ps1` and `config.json` from the GitHub raw URL
4. **Launch:** Dot-source and invoke the GUI

---

## GUI Design

**Theme:** Dark mode. Background `#1E1E1E`, surface `#2D2D2D`, accent `#0078D4` (Windows blue), text `#F0F0F0`. Clean, flat, no gradients.

**Header (always visible):**
- Tool title: "VITS Windows Debloater"
- Machine hostname and current username
- Small VITS branding

**Four tabs:**

### Tab 1: Debloat

- On launch, run `winget list` and `Get-AppxPackage` to detect installed apps
- Cross-reference results against `config.json` debloat list
- Only render checkboxes for apps that are actually installed on this machine
- All detected items are **pre-ticked** by default
- Tech unticks anything they want to keep
- "Run Debloat" button at the bottom
- Live scrollable log output panel shows progress
- On completion: prompt "Some changes require a restart. Restart now?" with Yes/No buttons (not forced)

### Tab 2: Install

- Render all apps from `config.json` install list
- All items **unticked** by default
- Tech ticks what to install
- "Run Install" button at the bottom
- Installs via `winget install --id <id> --silent --accept-package-agreements --accept-source-agreements`
- Live scrollable log output panel shows progress

### Tab 3: Updates

- Single "Run Winget Updates" button
- Executes `winget upgrade --all --silent --accept-package-agreements --accept-source-agreements`
- Live scrollable log output panel shows progress

---

## config.json Structure

```json
{
  "debloat": [
    {
      "name": "Lenovo AI Now",
      "type": "winget",
      "id": "Lenovo.AIPlugin"
    },
    {
      "name": "Xbox Game Bar",
      "type": "appx",
      "id": "Microsoft.XboxGamingOverlay"
    }
  ],
  "install": [
    {
      "name": "Google Chrome",
      "id": "Google.Chrome"
    },
    {
      "name": "7-Zip",
      "id": "7zip.7zip"
    }
  ]
}
```

Each debloat entry has a `type`: `winget` (use `winget uninstall`) or `appx` (use `Remove-AppxPackage`). Some items may need both attempted.

---

## Full App Lists

### Debloat List

| App | Type |
|---|---|
| Lenovo AI Now | winget |
| Lenovo Smart Meeting | winget |
| Lenovo Speech | winget |
| Xbox Game Bar | appx |
| Xbox Game Pass | appx/winget |
| Xbox App | appx |
| Microsoft Cortana | appx |
| Microsoft Clipchamp | appx |
| Microsoft Tips | appx |
| Get Started | appx |
| Microsoft Weather | appx |
| Microsoft News | appx |
| Microsoft Maps | appx |
| Microsoft Solitaire Collection | appx |

### Install List

| App | Winget ID |
|---|---|
| Google Chrome | Google.Chrome |
| Mozilla Firefox | Mozilla.Firefox |
| 7-Zip | 7zip.7zip |
| Adobe Acrobat Reader | Adobe.Acrobat.Reader.64-bit |
| Notepad++ | Notepad++.Notepad++ |
| VLC | VideoLAN.VLC |
| Microsoft 365 | Microsoft.Office |
| Microsoft Teams | Microsoft.Teams |
| Bitwarden | Bitwarden.Bitwarden |
| LastPass | LastPass.LastPass |
| Dropbox | Dropbox.Dropbox |
| Everything (Void Tools) | voidtools.Everything |
| PowerShell (latest) | Microsoft.PowerShell |
| Python (latest) | Python.Python.3 |
| Signal | OpenWhisperSystems.Signal |
| Windows Terminal | Microsoft.WindowsTerminal |
| Webex (Cisco) | Cisco.Webex |
| WhatsApp | WhatsApp.WhatsApp |
| VS Code | Microsoft.VisualStudioCode |
| Power BI Desktop | Microsoft.PowerBIDesktop |
| Git for Windows | Git.Git |

---

### Tab 4: About

- Static info page
- "VITS | Ravi Singh" credit
- Clickable link to the GitHub repo: `https://github.com/VITS-Ltd/Windows-Debloater`
- Tool version (pulled from config.json or hardcoded)

---

## Key Constraints

- No log file saved to disk - output is visual only in the GUI
- OneDrive is explicitly excluded from debloat
- All winget commands run with `--silent --accept-package-agreements --accept-source-agreements`
- GUI must remain responsive during operations (use PowerShell runspaces or jobs for background execution)
- Script must work on Windows 11 out of the box, no dependencies beyond what ships with the OS
