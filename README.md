# Game Mode

A Windows terminal utility that toggles a set of system optimizations with a single keypress to squeeze out extra gaming performance.

Requires **Windows Terminal** and must be run as **Administrator**.

## What it does

Pressing Enter in the menu simultaneously applies (or reverts) the following:

| Module | Game Mode ON | Game Mode OFF |
|---|---|---|
| **Power Plan** | Ultimate Performance | Balanced |
| **Windows Explorer** | Killed (frees RAM + CPU) | Relaunched |
| **Windows Defender** | Real-time protection disabled | Re-enabled |
| **SysMain** (Superfetch) | Service stopped | Service started |
| **Network Throttling** | Disabled (`NetworkThrottlingIndex = 0xFFFFFFFF`) | Restored to default |

State is detected from Explorer and Power Plan — these are the reliable visible indicators. The menu shows the current state on each redraw and restores everything automatically when you quit or close the window.

## Usage

Double-click **`Game Optimizer.bat`**. It opens in Windows Terminal and self-elevates to Administrator.

```
  ██████╗  █████╗ ███╗   ███╗███████╗
 ...
  Enable Game Mode
  [Press Enter]

  [Q] Quit
```

- **Enter** — toggle all optimizations on or off
- **Q** — quit and auto-restore defaults if game mode is active

## Auto-launch with Steam

To have Game Mode open automatically whenever Steam starts, run the setup script once:

```powershell
# Run as Administrator
.\game-mode-wmi-setup.ps1
```

This registers a WMI event subscription that fires when `steam.exe` is created, triggering a scheduled task that launches the optimizer in your interactive session.

To remove it:

```powershell
.\game-mode-wmi-uninstall.ps1
```

## To-do

- [ ] **Customize menu** — let the user toggle which modules are active (Power Plan, Explorer, Defender, SysMain, Network Throttling) before applying, accessible via a `[C] Customize` key in the main menu

## Requirements

- Windows 10/11
- Windows Terminal (`wt.exe`)
- PowerShell 5.1+
- Administrator privileges
- Ultimate Performance power plan available (built into Windows 10 1803+ Pro/Enterprise; may need to be [unhidden](https://www.howtogeek.com/368781/how-to-enable-ultimate-performance-power-plan-in-windows-10/) on Home)
