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

Each module can be individually enabled or disabled via **Settings → Configure Game Mode**, so you can choose which optimizations apply when you press Enter. Your choices are saved to `_core/.module-config.json` and restored automatically on next launch.

State is detected from the enabled Explorer and Power Plan modules — these are the reliable visible indicators. The menu shows the current state on each redraw and restores everything automatically when you quit or close the window.

## Usage

Double-click **`Game Optimizer.bat`**. It opens in Windows Terminal and self-elevates to Administrator.

```
  ██████╗  █████╗ ███╗   ███╗███████╗
 ...
  Enable Game Mode
  [Press Enter]

  [Q] Quit
```

- **Enter** — toggle all enabled optimizations on or off
- **S** — open Settings (audio device, module configuration, Tamper Protection)
- **Q** — quit and auto-restore defaults if game mode is active

## Crash recovery

If the optimizer exits unexpectedly while game mode is active (terminal killed, machine crash, power loss), system settings are left in their gaming state. To auto-restore them at next logon, run the recovery setup script once:

```powershell
# Run as Administrator
.\game-mode-recovery-setup.ps1
```

This registers a `GameModeRecovery` scheduled task that fires at logon, checks for a sentinel file written when game mode is enabled, and restores all settings if found. The sentinel is deleted on any clean exit, so the task does nothing on normal sessions.

To remove it:

```powershell
.\game-mode-recovery-uninstall.ps1
```

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

### ~~`[T]` gives no instruction to return after opening Windows Security~~ *(fixed)*

Pressing `[T]` now opens a dedicated Tamper Protection screen that shows the current status and polls every 500ms. The status updates immediately when Tamper Protection is toggled in Windows Security. Press `[B]` to return to Settings.

### No auto-elevation — script must be run as Administrator

Self-elevation was removed. If the script is launched without admin rights it exits immediately with a message instructing the user to re-launch as Administrator.

The previous auto-elevation approach re-launched `powershell.exe` with `-Verb RunAs`, which worked but always opened a plain conhost window instead of Windows Terminal. An earlier attempt to elevate via `wt.exe` caused an **infinite UAC loop** on some systems, locking user accounts. Removing auto-elevation sidesteps both problems cleanly.

### `Get-SettingsAlert` runs expensive operations on every menu redraw

Every loop iteration (every keypress) calls `Get-Module -ListAvailable -Name AudioDeviceCmdlets` (filesystem scan), `powercfg /list` (subprocess), and `Get-MpComputerStatus` (WMI query). These results don't change between keypresses, so the repeated work causes perceptible lag on each redraw.

### ~~`finally` cleanup block has no per-step error handling~~ *(fixed)*

Each of the five cleanup calls in `finally` is now wrapped in its own `try/catch`, so a failure in one step no longer skips the rest. The logon recovery task (`game-mode-recovery-setup.ps1`) covers the crash/force-kill case where `finally` never runs at all.

### Network Throttling restores to hardcoded defaults, not original values

When game mode is disabled, `NetworkThrottlingIndex` is always written back to `10` and `SystemResponsiveness` to `20`. If the user had non-default values before enabling game mode, those values are permanently overwritten. The module has no mechanism to save the pre-existing values.

### Explorer kill loop has no timeout

After `taskkill /f /im explorer.exe`, the module polls until the process disappears:
```powershell
while (Get-Process explorer -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 100 }
```
If Explorer refuses to terminate (e.g. blocked by an open file dialog), this loop never exits and the script hangs indefinitely.

### Audio device picker is limited to 9 devices

The audio device menu in Settings reads a single keypress and parses it as a digit character. Only devices numbered 1–9 are reachable; any device at index 10 or higher cannot be selected.

### `Set-SysMain` can fail if the service is set to Disabled

`Start-Service SysMain` throws if SysMain's startup type is `Disabled` (as opposed to merely stopped). The error propagates to the menu's `catch` block and aborts the entire disable-game-mode action, leaving the other four modules in their gaming state.

## Requirements

- Windows 10/11
- Windows Terminal (`wt.exe`)
- PowerShell 5.1+
- Administrator privileges
- Ultimate Performance power plan available (built into Windows 10 1803+ Pro/Enterprise; may need to be [unhidden](https://www.howtogeek.com/368781/how-to-enable-ultimate-performance-power-plan-in-windows-10/) on Home)
