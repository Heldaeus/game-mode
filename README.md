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

## Known issues

### STATUS shows ENABLED even if Defender was not actually toggled

`$on` (the game mode state indicator) is derived from Explorer and Power Plan only. If Defender's real-time protection fails to toggle — most commonly because Tamper Protection is blocking it — the menu still reports ENABLED. The Settings screen will show a warning when Tamper Protection is detected, but the main menu gives no indication that the toggle was partially applied.

### Settings alert asterisk can go stale

The `*` next to `[S] Settings` is computed once at startup and once on return from Settings. If the user changes a relevant system setting externally (e.g. disabling Tamper Protection via Windows Security without going through the `[T]` prompt), the asterisk won't clear until the user opens and closes Settings.

### Crash before friendly error handler if WMI is unavailable

`Get-SettingsAlert` (which checks Tamper Protection via `Get-MpComputerStatus`) runs before the `try/catch` that wraps the menu loop. If the WMI service is unavailable, the script exits with a raw PowerShell error instead of the "Press Enter to close" prompt.

### `[T]` gives no instruction to return after opening Windows Security

Pressing `[T]` in Settings opens Windows Security to the Tamper Protection toggle but leaves no prompt in the terminal telling the user to come back. The Settings screen does self-correct on the next keypress — it rechecks `IsTamperProtected` at the top of each loop iteration — but the user has no visual cue that this will happen.

### Self-elevation opens a plain PowerShell window instead of Windows Terminal

The script elevates by re-launching `powershell.exe` directly with `-Verb RunAs`. This works reliably but loses the Windows Terminal chrome.

The previous approach — elevating `wt.exe` and having it spawn PowerShell — caused an **infinite UAC loop**: WT does not reliably propagate its elevated token to the PowerShell process it spawns inside a tab, so the `IsInRole(Administrator)` check kept failing in the new window and the script kept spawning UAC prompts. On a system with an account lockout policy this locked the user account.

**Potential workaround to investigate:** Windows Terminal 1.18+ added an `--elevate` flag (`wt --elevate new-tab powershell.exe ...`) and per-profile `"elevate": true` in `settings.json`. Either could allow self-elevation inside WT properly, but both depend on the user's WT version and profile configuration, making them fragile as a general solution. Worth revisiting if a clean WT-native elevation path can be confirmed.

## To-do

- [ ] **Customize menu** — let the user toggle which modules are active (Power Plan, Explorer, Defender, SysMain, Network Throttling) before applying, accessible via a `[C] Customize` key in the main menu

## Requirements

- Windows 10/11
- Windows Terminal (`wt.exe`)
- PowerShell 5.1+
- Administrator privileges
- Ultimate Performance power plan available (built into Windows 10 1803+ Pro/Enterprise; may need to be [unhidden](https://www.howtogeek.com/368781/how-to-enable-ultimate-performance-power-plan-in-windows-10/) on Home)
