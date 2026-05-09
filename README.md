# Game Mode

A Windows terminal utility that toggles a set of system optimizations with a single keypress to squeeze out extra gaming performance.

Requires **Windows Terminal** and must be run as **Administrator**.

## What it does

Pressing Enter in the menu simultaneously applies (or reverts) the following:

| Module | Game Mode ON | Game Mode OFF |
|---|---|---|
| **Power Plan** | Ultimate Performance (High Performance fallback) | Balanced |
| **Windows Explorer** | Killed (frees RAM + CPU) | Relaunched |
| **Windows Defender** | Real-time protection disabled | Re-enabled |
| **SysMain** (Superfetch) | Service stopped | Service started |
| **Network Throttling** | Disabled (`NetworkThrottlingIndex = 0xFFFFFFFF`) | Restored to default |
| **Timer Resolution** | Set to 0.5ms via `NtSetTimerResolution` (background helper) | Helper killed, resolution restored |
| **Priority Separation** | `Win32PrioritySeparation = 0x26` (short, fixed, max foreground boost) | Original value restored |

Each module can be individually enabled or disabled via **Settings → Configure Game Mode**. Your choices are saved to `_core/.module-config.json` and restored automatically on next launch.

State is detected from the enabled Explorer, Power Plan, Timer Resolution, and Priority Separation modules. The menu shows ON/OFF on each redraw and restores everything automatically when you quit or close the window.

## Usage

Right-click **`Game Optimizer.bat`** and select **Run as Administrator**. It opens in Windows Terminal.

- **Enter** — toggle all enabled optimizations on or off
- **S** — open Settings
- **Q** — quit and auto-restore defaults if game mode is active

## Settings

Accessible via **S** from the main menu.

- **[1] Audio Device** — switch the default playback device (requires AudioDeviceCmdlets)
- **[C] Configure Game Mode** — toggle individual modules on/off; each shows DISABLED / READY / ON
- **[G] GPU MSI Mode** — one-time setup to enable Message Signaled Interrupts on all GPUs (reboot required)
- **[D] Dynamic Tick** — toggle `disabledynamictick` in BCD to force constant timer interrupts (reboot required)
- **TAB** — go back from any screen

Yellow alert prompts appear in Settings for any missing prerequisites (AudioDeviceCmdlets, Ultimate Performance plan, Tamper Protection enabled).

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

### STATUS shows ON even if Defender was not actually toggled

`$on` (the game mode state indicator) is derived from Explorer, Power Plan, Timer Resolution, and Priority Separation. If Defender's real-time protection fails to toggle — most commonly because Tamper Protection is blocking it — the menu still reports ON. The Settings screen will show a warning when Tamper Protection is detected, but the main menu gives no indication that the toggle was partially applied.

### Settings alert asterisk can go stale

The `*` next to `[S] Settings` is computed once at startup and once on return from Settings. If the user changes a relevant system setting externally (e.g. disabling Tamper Protection via Windows Security without going through the `[T]` prompt), the asterisk won't clear until the user opens and closes Settings.

### Crash before friendly error handler if WMI is unavailable

`Get-SettingsAlert` (which checks Tamper Protection via `Get-MpComputerStatus`) runs before the `try/catch` that wraps the menu loop. If the WMI service is unavailable, the script exits with a raw PowerShell error instead of the "Press Enter to close" prompt.

### No auto-elevation — script must be run as Administrator

Self-elevation was removed. If the script is launched without admin rights it exits immediately with a message instructing the user to re-launch as Administrator.

The previous auto-elevation approach re-launched `powershell.exe` with `-Verb RunAs`, which worked but always opened a plain conhost window instead of Windows Terminal. An earlier attempt to elevate via `wt.exe` caused an **infinite UAC loop** on some systems, locking user accounts. Removing auto-elevation sidesteps both problems cleanly.

### `Get-SettingsAlert` runs expensive operations on every menu redraw

Every loop iteration (every keypress) calls `Get-Module -ListAvailable -Name AudioDeviceCmdlets` (filesystem scan), `powercfg /list` (subprocess), and `Get-MpComputerStatus` (WMI query). These results don't change between keypresses, so the repeated work causes perceptible lag on each redraw.

### Network Throttling restores to hardcoded defaults, not original values

When game mode is disabled, `NetworkThrottlingIndex` is always written back to `10` and `SystemResponsiveness` to `20`. If the user had non-default values before enabling game mode, those values are permanently overwritten. The module has no mechanism to save the pre-existing values.

### Explorer kill loop has no timeout

After `taskkill /f /im explorer.exe`, the module polls until the process disappears:
```powershell
while (Get-Process explorer -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 100 }
```
If Explorer refuses to terminate (e.g. blocked by an open file dialog), this loop never exits and the script hangs indefinitely.

### Power Plan module config page does not reflect High Performance fallback

When Ultimate Performance is unavailable, game mode silently falls back to High Performance. The description line on the Power Plan config page (`Settings → Configure Game Mode → [2]`) still reads "Switches to Ultimate Performance or High Performance power plan" regardless. It should detect whether Ultimate Performance is provisioned and update the description accordingly — e.g. *"Switches to High Performance power plan."* — and show an alert prompt (matching the Tamper Protection pattern on the Defender page) offering to provision Ultimate Performance via `powercfg /duplicatescheme`.

### Audio device picker is limited to 9 devices

The audio device menu in Settings reads a single keypress and parses it as a digit character. Only devices numbered 1–9 are reachable; any device at index 10 or higher cannot be selected.

### Timer Resolution has no effect on games on Windows 11 / Windows 10 2004+

On Windows 11 and Windows 10 post-2004, timer resolution is scoped per-process: a process calling `NtSetTimerResolution` only changes the resolution for itself, not system-wide. The background helper holds 0.5ms for its own process only — games and other applications are unaffected unless they independently request a lower resolution. The module has no practical impact on gaming performance on modern Windows builds.

### `Set-SysMain` can fail if the service is set to Disabled

`Start-Service SysMain` throws if SysMain's startup type is `Disabled` (as opposed to merely stopped). The error propagates to the menu's `catch` block and aborts the entire disable-game-mode action, leaving the other modules in their gaming state.

## Requirements

- Windows 10/11
- Windows Terminal (`wt.exe`)
- PowerShell 5.1+
- Administrator privileges
- Ultimate Performance power plan available (built into Windows 10 1803+ Pro/Enterprise; may need to be [unhidden](https://www.howtogeek.com/368781/how-to-enable-ultimate-performance-power-plan-in-windows-10/) on Home)
