# Game Mode — How It Works (Deep Documentation)

This document explains every file in the project in plain English. It is written for someone who can read but doesn't write code — the goal is that if something breaks, you can understand what went wrong and why, even if you can't fix it yourself on the first try.

---

## Table of Contents

1. [The Big Picture](#1-the-big-picture)
2. [File Map](#2-file-map)
3. [How a Toggle Actually Works (Step-by-Step)](#3-how-a-toggle-actually-works-step-by-step)
4. [File-by-File Breakdown](#4-file-by-file-breakdown)
   - [Game Optimizer.bat](#game-optimizerbat)
   - [_core/menu.ps1](#_coremenups1)
   - [_core/settings.ps1](#_coresettingsps1)
   - [Explorer/_module.ps1](#explorer_moduleps1)
   - [Power Plan/_module.ps1](#power-plan_moduleps1)
   - [Defender/_module.ps1](#defender_moduleps1)
   - [SysMain/_module.ps1](#sysmain_moduleps1)
   - [Network Throttling/_module.ps1](#network-throttling_moduleps1)
   - [Timer Resolution/_module.ps1](#timer-resolution_moduleps1)
   - [Timer Resolution/_helper.ps1](#timer-resolution_helperps1)
   - [Priority Separation/_module.ps1](#priority-separation_moduleps1)
   - [game-mode-wmi-setup.ps1](#game-mode-wmi-setupps1)
   - [game-mode-wmi-uninstall.ps1](#game-mode-wmi-uninstallps1)
   - [_core/recovery.ps1](#_corerecoveryps1)
   - [game-mode-recovery-setup.ps1](#game-mode-recovery-setupps1)
   - [game-mode-recovery-uninstall.ps1](#game-mode-recovery-uninstallps1)
5. [What "Game Mode ON" Actually Does to Your PC](#5-what-game-mode-on-actually-does-to-your-pc)
6. [The Auto-Restore Safety Net](#6-the-auto-restore-safety-net)
7. [The WMI Auto-Launch System](#7-the-wmi-auto-launch-system)
8. [Common Problems and What Causes Them](#8-common-problems-and-what-causes-them)
9. [Glossary of Terms](#9-glossary-of-terms)

---

## 1. The Big Picture

Game Mode is a tool that lives in Windows Terminal. When you run it, you get a menu that looks like this:

```
  ░██████╗░░█████╗░███╗░░░███╗███████╗
  ...GAME MODE...

  ╔═══════════════════════════════════╗
  ║         STATUS: OFF               ║
  ╚═══════════════════════════════════╝

  [PRESS ENTER] Enable Game Mode

  [S] Settings
  [Q] Quit
```

You press **Enter** once to turn on a collection of Windows optimizations that free up CPU and RAM for gaming. You press **Enter** again (or **Q**) to put everything back to normal. That's it from the user's perspective.

Under the hood, pressing Enter triggers up to seven separate system changes at the same time:

| What gets changed | Gaming State | Normal State |
|---|---|---|
| Power Plan | Ultimate Performance (High Performance on systems where Ultimate isn't available) | Balanced |
| Windows Explorer | Killed (taskbar disappears) | Running normally |
| Windows Defender | Real-time scanning OFF | Real-time scanning ON |
| SysMain (Superfetch) | Stopped | Running |
| Network Throttling | Disabled | Windows default |
| Timer Resolution | 0.5ms (via background helper process) | Default (~15.625ms) |
| Priority Separation | 0x26 (short quanta, fixed, max foreground boost) | Original value restored |

Each of these is a separate module that can be individually enabled or disabled in **Settings → Configure Game Mode**. The tool is designed with one important safety rule: **it always puts things back**. If you quit, if you close the window, or if the script crashes — it detects that game mode is active and restores all settings before exiting.

---

## 2. File Map

```
game-mode/
│
├── Game Optimizer.bat               ← The file you double-click to start everything
│
├── _core/
│   ├── menu.ps1                     ← The brain: draws the UI, reads your keypresses,
│   │                                   calls the modules, handles cleanup on exit
│   ├── settings.ps1                 ← Settings screens: audio device switcher,
│   │                                   Configure Game Mode (per-module toggles),
│   │                                   GPU MSI Mode, Dynamic Tick,
│   │                                   power plan provisioning, Tamper Protection
│   ├── recovery.ps1                 ← Crash recovery: restores settings at logon if
│   │                                   the script was killed while game mode was on
│   ├── .game-mode-active            ← Sentinel file (created on enable, deleted on
│   │                                   disable; its presence means a crash recovery
│   │                                   may be needed — not tracked by git)
│   ├── .module-config.json          ← Saved module on/off choices (written on every
│   │                                   toggle, loaded at startup — not tracked by git)
│   └── .priority-sep-original       ← Saved Win32PrioritySeparation value (written on
│                                       game mode enable, deleted on disable — not tracked)
│
├── Explorer/
│   └── _module.ps1                  ← Kills/restarts Windows Explorer (taskbar, desktop)
│
├── Power Plan/
│   └── _module.ps1                  ← Switches between Balanced and Ultimate Performance
│
├── Defender/
│   └── _module.ps1                  ← Turns Windows Defender real-time protection on/off
│
├── SysMain/
│   └── _module.ps1                  ← Stops/starts the SysMain (Superfetch) service
│
├── Network Throttling/
│   └── _module.ps1                  ← Edits registry keys to disable/restore network throttling
│
├── Timer Resolution/
│   ├── _module.ps1                  ← Launches/kills the helper; tracks its PID
│   └── _helper.ps1                  ← Background process that holds the 0.5ms resolution
│
├── Priority Separation/
│   └── _module.ps1                  ← Reads/writes Win32PrioritySeparation registry value
│
├── game-mode-wmi-setup.ps1          ← Optional: makes Game Mode auto-open when Steam starts
├── game-mode-wmi-uninstall.ps1      ← Optional: undoes what wmi-setup.ps1 did
├── game-mode-recovery-setup.ps1     ← Optional: registers logon recovery task for crash safety
└── game-mode-recovery-uninstall.ps1 ← Optional: removes the logon recovery task
```

Each `_module.ps1` file contains exactly two functions: one that **reads the current state** of that setting, and one that **changes it**. The Timer Resolution module is a slight exception — its state is determined by whether a background helper process is alive, not by a registry value or service status.

---

## 3. How a Toggle Actually Works (Step-by-Step)

Here is the full journey from double-click to your screen going back to normal, written as a sequence of events:

1. **You double-click `Game Optimizer.bat`.**

2. **The .bat file runs one line:** it opens Windows Terminal (`wt.exe`) and tells it to run `_core/menu.ps1` in a new PowerShell window, with the execution policy bypassed.

3. **`menu.ps1` wakes up.** The first thing it does is check: *am I running as Administrator?* If not, it prints an error in red and exits immediately — you must re-launch the `.bat` file as Administrator manually.

4. **The modules are loaded.** The script uses dot-sourcing (`. "path\to\file.ps1"`) to load all seven module files and `_core\settings.ps1` into its own memory. Loading `settings.ps1` also initializes the `$script:ModuleEnabled` table, which records which modules the user has configured to be active (all seven are on by default).

5. **The menu loop begins.** The script enters a loop that keeps running until you press Q.

6. **On every loop iteration, the screen is cleared and redrawn.** Before drawing, it checks the state of whichever modules the user has enabled. For Explorer: is it stopped? For Power Plan: is it Ultimate Performance? For Timer Resolution: is the helper process alive? For Priority Separation: is the registry value 0x26? If all enabled indicators agree game mode is on, the status box shows ON. The status and the button label update accordingly.

7. **The script waits for a keypress** using `[Console]::ReadKey($true)`. The `$true` means the keypress is not echoed to the screen.

8. **If you press Enter:**
   - If game mode is currently OFF → it calls the "enable" function for each module that is toggled on in Configure Game Mode, then writes a small sentinel file (`_core\.game-mode-active`) to disk.
   - If game mode is currently ON → it calls the "disable" function for each enabled module, then deletes the sentinel file.
   - Either way, the loop immediately repeats, clearing and redrawing the screen.

9. **If you press S:** `Show-Settings` is called. All settings screens use TAB to go back a level.

10. **If you press Q:** the loop variable `$running` is set to `false`, the loop ends.

11. **The `finally` block runs.** This guaranteed cleanup step runs even if the script crashes mid-loop. It checks if game mode is on (using the same indicators as step 6), and if so turns everything off with per-step error handling so a failure in one module doesn't skip the rest. The sentinel file is deleted at the end.

---

## 4. File-by-File Breakdown

---

### `Game Optimizer.bat`

```bat
@echo off
wt.exe powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0_core\menu.ps1"
```

**Line 1 — `@echo off`:** Tells the command prompt not to print each command to the screen as it runs.

**Line 2:** This is the entire logic of the file. Breaking it down piece by piece:

- `wt.exe` — launches Windows Terminal. If Windows Terminal is not installed, this line fails and nothing opens.
- `powershell.exe` — tells Windows Terminal to open a PowerShell session.
- `-NoProfile` — tells PowerShell not to load your personal profile script (which might contain settings or customizations that could interfere).
- `-ExecutionPolicy Bypass` — overrides Windows' default restriction on running PowerShell scripts.
- `-File "%~dp0_core\menu.ps1"` — the script file to run. `%~dp0` is a special .bat variable that means "the folder where this .bat file lives."

**What can go wrong here:** If `wt.exe` (Windows Terminal) is not installed, nothing happens — the window flashes and closes. Solution: install Windows Terminal from the Microsoft Store.

---

### `_core/menu.ps1`

This is the main brain of the entire project. It has four sections.

#### Section 1 — Elevation Check

Checks whether the current process is running as Administrator. If not, it prints an error in red, waits for Enter, and exits. There is no automatic re-launch.

**Why auto-elevation was removed:** An earlier version re-launched `powershell.exe` with `-Verb RunAs` to trigger a UAC prompt automatically. This worked but always opened a plain `conhost.exe` window instead of Windows Terminal. A subsequent attempt to elevate via `wt.exe -Verb RunAs` caused an infinite UAC loop on some systems. Removing auto-elevation sidesteps both problems cleanly.

#### Section 2 — Module Loading

```powershell
$root = Split-Path (Split-Path $PSCommandPath -Parent) -Parent
. "$root\Explorer\_module.ps1"
. "$root\Power Plan\_module.ps1"
. "$root\Defender\_module.ps1"
. "$root\SysMain\_module.ps1"
. "$root\Network Throttling\_module.ps1"
. "$root\Timer Resolution\_module.ps1"
. "$root\Priority Separation\_module.ps1"
. "$root\_core\settings.ps1"
```

`$PSCommandPath` is a built-in variable containing the full path to the currently running script. Two `Split-Path -Parent` calls walk up to the project root, stored in `$root`.

The `. "$root\..."` lines use **dot-sourcing** — run this file and bring everything it defines into the current scope. All seven modules and settings.ps1 are loaded once at startup; their functions are then available everywhere.

**What can go wrong:** If any module file is missing or has a syntax error, the dot-source fails and the entire script crashes before the menu draws.

#### Section 3 — Helper Functions

`Get-ArtColor` and `Write-Art` draw the ASCII art logo in two colors (dark gray for box-drawing characters, white for everything else). Cosmetic only.

#### Section 4 — The Menu Loop

The core of the script, inside a `try/catch/finally` block.

**State detection:**

```powershell
$indicators = @()
if ($script:ModuleEnabled['Explorer'])          { $indicators += (Get-ExplorerState) -eq 'Stopped' }
if ($script:ModuleEnabled['Power Plan'])        { $indicators += (Get-PowerPlanState) -eq 'Ultimate Performance' }
if ($script:ModuleEnabled['Timer Resolution'])  { $indicators += (Get-TimerResState) -eq 'Active' }
if ($script:ModuleEnabled['Priority Separation']) { $indicators += (Get-PrioritySepState) -eq 'Gaming' }
$on = $indicators.Count -gt 0 -and ($indicators -notcontains $false)
```

All enabled indicators must agree that game mode is on. Defender, SysMain, and Network Throttling are treated as "side effects" — they're toggled but not used as state indicators.

**The toggle logic** calls each enabled module's `Set-*` function in sequence, then writes or deletes the sentinel file. Each module is guarded by a check against `$script:ModuleEnabled` so disabled modules are skipped entirely.

**The `finally` block** runs the same indicator check and calls each module's disable function if game mode is detected as on. Each call is individually wrapped in `try/catch` so a failure in one step does not cause the others to be skipped.

---

### `_core/settings.ps1`

This file defines the module configuration table, all settings screens, and the one-time setup screens.

#### `$script:ModuleEnabled`

```powershell
$script:ModuleEnabled = [ordered]@{
    Explorer             = $true
    'Power Plan'         = $true
    Defender             = $true
    SysMain              = $true
    'Network Throttling' = $true
    'Timer Resolution'   = $true
    'Priority Separation' = $true
}
```

The source of truth for which modules participate in a game mode toggle. Initialized with all seven enabled, then immediately overridden by any saved values in `_core\.module-config.json`. Changes are written to that file on every toggle and reloaded from it on every launch.

On startup, if Tamper Protection is detected, the Defender module is automatically set to `$false` in memory (without touching the saved config), so it won't silently fail when game mode enables. If Tamper Protection is later turned off in the Defender module config page, the saved preference is restored.

#### `Show-ConfigureGameMode`

Displays a numbered list of all seven modules. Each shows its current state:
- **DISABLED** (red) — module is toggled off in config
- **READY** (white) — module is on in config, game mode is currently off
- **ON** (green) — module is on in config and game mode is currently active

The current state is determined by checking whether the sentinel file `_core\.game-mode-active` exists. This makes the list reflect live game mode state when you navigate settings mid-session.

Pressing a number opens that module's individual config screen (`Show-ModuleConfig`). TAB goes back.

#### `Show-ModuleConfig`

A generic screen for one module at a time. Shows the same three-state DISABLED / READY / ON status, a short description of what the module does, `[T]` to toggle, and TAB to go back. The Defender screen has special handling: if Tamper Protection is active, the module is shown as Locked and `[T]` opens the Tamper Protection screen instead of toggling.

#### `Show-Settings`

The top-level settings screen. Shows:
- `[1] Audio Device` — if AudioDeviceCmdlets is installed
- `[C] Configure Game Mode` — always visible
- `[G] GPU MSI Mode` — always visible
- `[D] Dynamic Tick` — always visible
- `[TAB] Back`
- Yellow warning prompts below for any missing prerequisites

#### `Show-AudioDevice`

Lists all playback audio devices. The currently active device is highlighted in green. Pressing a number switches to that device using `Set-AudioDevice` from the AudioDeviceCmdlets module.

#### `Show-TamperProtection`

Opens the Windows Security threat settings page automatically, then polls `Get-MpComputerStatus` every 500ms. The status line updates live as Tamper Protection is toggled. TAB to go back.

#### `Get-GpuMsiInfo` / `Show-GpuMsi`

`Get-GpuMsiInfo` enumerates all display devices via `Get-PnpDevice` and reads the `MSISupported` registry value from each GPU's interrupt management key. `Show-GpuMsi` displays the current state for each GPU (Enabled / Disabled / Unknown) and offers `[E]` to set `MSISupported = 1` on all GPUs. Changes require a reboot and are permanent until manually reverted — this is a one-time setup, not toggled with game mode.

#### `Get-DynamicTickState` / `Show-DynamicTick`

`Get-DynamicTickState` calls `bcdedit /enum {current}` and checks whether `disabledynamictick` is set to `Yes`. `Show-DynamicTick` shows the current state and offers `[D]` to disable dynamic tick (sets `disabledynamictick yes` in BCD) or `[E]` to re-enable it (deletes the value). Changes require a reboot and are reversible from the same screen.

---

### `Explorer/_module.ps1`

Manages Windows Explorer — the process that runs your desktop, taskbar, and file manager windows.

#### `Get-ExplorerState`

```powershell
function Get-ExplorerState {
    if (Get-Process explorer -ErrorAction SilentlyContinue) { 'Running' } else { 'Stopped' }
}
```

`Get-Process explorer` looks for a running process named `explorer`. `-ErrorAction SilentlyContinue` silently swallows the "not found" condition instead of printing an error.

#### `Set-Explorer`

When stopping: uses `taskkill /f /im explorer.exe` to kill all Explorer instances simultaneously (using `Stop-Process` is too slow — Windows auto-restarts Explorer between kills). After `taskkill`, polls every 100ms until Explorer is truly gone before returning.

When starting: `Start-Process explorer` with no arguments re-launches the full shell (taskbar + desktop).

---

### `Power Plan/_module.ps1`

Controls which Windows power plan is active using hardcoded GUIDs:
- Ultimate Performance: `e9a42b02-d5df-448d-aa00-03f14749eb61`
- High Performance: `8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c`
- Balanced: `381b4222-f694-41f0-9685-ff5bb260df2e`

`Get-PowerPlanState` calls `powercfg /getactivescheme` and checks which GUID is in the output. `Set-PowerPlan` calls `powercfg /setactive <GUID>`. When setting Ultimate Performance, if the command fails (plan not provisioned on this machine), it falls back to High Performance automatically.

**What can go wrong:** If neither the Ultimate nor High Performance plan is provisioned, the power plan toggle will silently fail. Use **Settings → Provision Ultimate Performance plan** to add it.

---

### `Defender/_module.ps1`

Toggles Windows Defender's real-time protection via `Get-MpComputerStatus` (to read) and `Set-MpPreference -DisableRealtimeMonitoring` (to write). Errors are caught silently — Tamper Protection blocking the call is handled at the settings/menu level, not inside the module.

**What can go wrong:** Tamper Protection blocks the `Set-MpPreference` call entirely. The Settings screen shows a warning and provides a path to disable Tamper Protection via the Windows Security UI.

---

### `SysMain/_module.ps1`

Stops and starts the SysMain (Superfetch) service via `Stop-Service SysMain -Force` and `Start-Service SysMain`. `-Force` ensures dependent services don't block the stop. Stopping is session-only — SysMain starts again on reboot.

---

### `Network Throttling/_module.ps1`

Edits two registry values:
- `HKLM:\...\Tcpip\Parameters\NetworkThrottlingIndex` — set to `0xFFFFFFFF` (gaming) or `10` (default)
- `HKLM:\...\Multimedia\SystemProfile\SystemResponsiveness` — set to `0` (gaming) or `20` (default)

Note: these restore to hardcoded Windows defaults, not the user's original values.

---

### `Timer Resolution/_module.ps1`

On Windows 11 and Windows 10 post-2004, timer resolution is **scoped per-process** — one process requesting 0.5ms does not change the resolution for the whole system; it only affects that process. To hold the resolution open for the duration of game mode, the module spawns a background helper process that keeps the request alive.

#### `Get-TimerResState`

Reads `_core\.timer-res-pid`. If the file exists and contains the PID of a running process, returns `'Active'`. Otherwise returns `'Inactive'`.

#### `Set-TimerRes`

When enabling: launches `Timer Resolution\_helper.ps1` as a hidden background PowerShell window using `Start-Process -WindowStyle Hidden -PassThru`. The returned process object's PID is written to `_core\.timer-res-pid`.

When disabling: reads the PID from the file, kills the process with `Stop-Process -Force`, and deletes the file.

---

### `Timer Resolution/_helper.ps1`

This is the background process kept alive during game mode. It does two things:

1. Uses P/Invoke (calling a Windows API function from PowerShell via compiled C#) to call `NtSetTimerResolution(5000, $true)`. The value `5000` is in 100-nanosecond units — 5000 × 100ns = 0.5ms.
2. Loops indefinitely with `Start-Sleep -Seconds 30` to stay alive.

When the module calls `Stop-Process` on this helper, Windows automatically releases the timer resolution request that process was holding, restoring the resolution to whatever the system default is.

**P/Invoke explained:** `NtSetTimerResolution` is a Windows NT internal function. PowerShell can't call it directly, but it can compile a tiny C# class (using `Add-Type`) that declares the function signature, and then call it through that class. This is called P/Invoke (Platform Invocation).

---

### `Priority Separation/_module.ps1`

Controls `Win32PrioritySeparation` in `HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl`. This registry value encodes how Windows allocates CPU scheduling quanta between the foreground window and background processes, split into three bit fields: quantum length, quantum type, and foreground boost.

The gaming value `0x26` (decimal 38) decodes as: short quanta, fixed length, maximum foreground boost. This tells Windows to give the foreground application (your game) the maximum CPU scheduling advantage.

#### `Get-PrioritySepState`

Reads the registry value and returns `'Gaming'` if it equals `0x26`, `'Default'` otherwise.

#### `Set-PrioritySep`

When enabling: reads the current value and saves it to `_core\.priority-sep-original`, then writes `0x26`.

When disabling: reads the saved value from `_core\.priority-sep-original`, restores it to the registry, and deletes the file. If the file doesn't exist (e.g. after a reboot where the value was already default), nothing is written. The change takes effect immediately — no reboot required.

---

### `game-mode-wmi-setup.ps1`

An optional, one-time setup script that makes the Game Optimizer launch automatically every time Steam starts.

**Why it's complicated:** WMI event consumers run as the SYSTEM account in Session 0 — an invisible background session. Windows opened from there never appear on your screen. The solution is a two-part chain:

1. **WMI subscription** — watches for `steam.exe` to start (runs as SYSTEM)
2. **Scheduled Task** — launches the Game Optimizer in your interactive session (appears on screen)

The WMI subscription fires when Steam starts, then triggers the Scheduled Task via `schtasks /run`. The task is configured to run as your normal logged-in user, so its window appears on your desktop.

The WMI filter polls every 3 seconds using: `SELECT * FROM __InstanceCreationEvent WITHIN 3 WHERE TargetInstance ISA 'Win32_Process' AND TargetInstance.Name = 'steam.exe'`.

---

### `game-mode-wmi-uninstall.ps1`

Removes the three WMI objects (binding first, then filter, then consumer) and the Scheduled Task. The binding must be removed before the filter and consumer, as it holds references to both. Every removal step is conditional — safe to run multiple times.

---

### `_core/recovery.ps1`

Invoked at logon by the `GameModeRecovery` scheduled task. Handles the case where the process was killed outright (terminal force-closed, machine crash) so the `finally` block never ran.

```powershell
if (-not (Test-Path $sentinelPath)) { exit 0 }
```

If the sentinel file doesn't exist, nothing needs recovering — exits in milliseconds. If it does exist, dot-sources all seven modules and calls their disable functions with per-step error handling:

```powershell
if ((Get-ExplorerState) -ne 'Running') { try { Set-Explorer $false }      catch {} }
try { Set-PowerPlan 'Balanced' }        catch {}
try { Set-Defender $false }             catch {}
try { Set-SysMain $false }              catch {}
try { Set-NetworkThrottle $false }      catch {}
try { Set-TimerRes $false }             catch {}
try { Set-PrioritySep $false }          catch {}
```

Explorer is checked before calling because Windows auto-relaunches it at logon — the script only acts if Explorer is genuinely not running.

The Timer Resolution module's disable function reads the PID file and tries to kill the process. After a reboot, that PID no longer exists, so the kill is a no-op — but the PID file is still cleaned up, preventing stale state.

The Priority Separation module's disable function restores from `_core\.priority-sep-original` if the file exists. After a reboot, the registry is unchanged from when it was written, so the restore still works correctly.

---

### `game-mode-recovery-setup.ps1`

Registers the `GameModeRecovery` scheduled task. Fires at every logon, runs with highest privileges (no UAC prompt), runs `_core\recovery.ps1` with `-ExecutionPolicy Bypass`.

---

### `game-mode-recovery-uninstall.ps1`

Removes the `GameModeRecovery` task. Safe to run multiple times.

---

## 5. What "Game Mode ON" Actually Does to Your PC

### Power Plan → Ultimate Performance (or High Performance)

Designed by Microsoft for workstations:
- Disables CPU park states (keeps all cores active)
- Disables PCIe Active State Power Management (keeps GPU link at full speed)
- Sets processor minimum state to 100% (CPU never downclocks)
- Eliminates timer coalescing (removes the batching delay Windows applies to timers)

Net effect: higher, more consistent CPU clock speeds and lower interrupt latency. Costs more power and generates more heat.

### Explorer → Killed

Windows Explorer runs the taskbar, Start menu, desktop, notification area, and File Explorer windows. When killed, all of that disappears. The game is unaffected — it runs in its own process.

**Why this helps:** Explorer continuously uses CPU and RAM polling for file changes, rendering the taskbar, and handling notifications. Removing it frees those resources.

**Important:** While Explorer is killed, the taskbar, Start menu, and file browser are unavailable. You can still Alt+Tab between running applications. When game mode is turned off, Explorer restarts and everything comes back.

### Windows Defender → Real-Time Protection Disabled

Real-time protection means: Defender constantly scans files as they are opened, created, or modified. This has a measurable CPU and disk I/O cost, especially during loading screens when games read many files quickly.

Disabling this does not permanently disable Defender, remove virus definitions, or affect scheduled scans. It only turns off continuous on-access scanning while you're gaming.

**Risk:** During game mode, if you download or run something malicious, Defender will not stop it in real time.

### SysMain (Superfetch) → Stopped

Superfetch pre-loads frequently used applications into RAM before you launch them. During gaming, this competes for RAM and causes background disk I/O. Stopping the service is session-only — SysMain starts again on reboot.

### Network Throttling → Disabled

- `NetworkThrottlingIndex = 0xFFFFFFFF` removes the Windows cap on non-multimedia network packets
- `SystemResponsiveness = 0` dedicates maximum CPU share to foreground/multimedia tasks

Can reduce latency jitter in online games where background traffic was competing with game packets.

### Timer Resolution → 0.5ms

By default, Windows fires its system timer approximately every 15.625ms. This is the minimum sleep granularity — when a process calls `Sleep(1ms)`, it actually sleeps ~15.6ms. Setting the resolution to 0.5ms makes timers fire 32× more frequently, reducing the coarseness of frame timing and sleep calls.

A background helper process (`Timer Resolution\_helper.ps1`) calls `NtSetTimerResolution(5000)` — where 5000 × 100ns = 0.5ms — and stays alive to keep the request active. On Windows 11 and post-2004 Windows 10, timer resolution is scoped per-process, so only this helper (and processes it affects) benefit. When the helper is killed on game mode disable, the resolution is automatically released.

**Effect:** More consistent frame times and slightly lower input latency. Does not meaningfully raise average FPS. Most relevant for competitive titles where frame time variance matters more than raw framerate.

### Priority Separation → 0x26

`Win32PrioritySeparation` encodes three bit fields that control CPU scheduling quantum allocation:

| Field | Gaming value (0x26) | Meaning |
|---|---|---|
| Quantum length | Short | Shorter time slices; more frequent context switches |
| Quantum type | Fixed | All processes get the same quantum length |
| Foreground boost | Max | Foreground app gets 3× the quantum of background processes |

**Net effect:** Your game (the foreground process) gets significantly more CPU scheduler time relative to background processes during each scheduling cycle.

---

## 6. The Auto-Restore Safety Net

There are two layers of protection that restore system settings when the script exits while game mode is active.

### Layer 1 — The `finally` block (in-process cleanup)

Runs in every exit scenario where the PowerShell process is still in control:
- Normal exit (Q pressed)
- An unhandled error inside the menu loop
- The terminal window closed with the X button

Checks the state indicators and if game mode is on, restores all seven modules with per-step error handling.

**What `finally` cannot cover:** If the PowerShell process is killed with no warning (e.g. `taskkill /f`, a machine crash, or a power outage), Windows terminates it immediately with no opportunity to run any cleanup code.

### Layer 2 — Sentinel file + logon recovery task (crash/kill cleanup)

**The sentinel file (`_core\.game-mode-active`):**

Written when game mode enables; deleted when it disables (by Enter toggle, Q, or `finally`). If the process is killed or machine crashes while game mode is on, the file remains on disk after reboot. It is not tracked by git.

**Runtime state files:**
- `_core\.timer-res-pid` — PID of the timer resolution helper process
- `_core\.priority-sep-original` — original `Win32PrioritySeparation` value before game mode changed it

These are also not tracked by git and are cleaned up on any normal game mode disable.

**The `GameModeRecovery` scheduled task (opt-in):**

If you have run `game-mode-recovery-setup.ps1`, a scheduled task fires at every logon. It runs `_core\recovery.ps1`, which checks for the sentinel and restores all seven settings if found.

| Scenario | `finally` runs? | Recovery task runs? |
|---|---|---|
| Q pressed (normal quit) | Yes | Sentinel deleted by `finally`, task does nothing |
| Terminal window X button | Yes (usually) | Sentinel deleted by `finally`, task does nothing |
| Terminal force-killed (`taskkill /f`) | No | Yes, at next logon |
| Machine crash / BSOD | No | Yes, at next logon |
| Power outage | No | Yes, at next logon |

Explorer is treated specially in the recovery task: since Windows auto-relaunches Explorer at logon, the task only calls `Set-Explorer` if Explorer is genuinely not running.

---

## 7. The WMI Auto-Launch System

This section covers the complete flow when `game-mode-wmi-setup.ps1` has been run and Steam starts.

```
Steam.exe starts
      ↓
WMI polls every 3 seconds for new Win32_Process instances
      ↓
WMI sees "steam.exe" was created → SteamGameModeFilter fires
      ↓
GameModeConsumer runs: schtasks.exe /run /tn "LaunchGameMode"
      ↓
Task Scheduler finds "LaunchGameMode" task and starts it
      ↓
Task runs as your interactive user: cmd.exe /c "Game Optimizer.bat"
      ↓
Game Optimizer.bat runs: wt.exe powershell.exe ... menu.ps1
      ↓
Windows Terminal opens on your screen with the Game Mode menu
```

**Why there's a 3-second delay:** The WMI filter uses `WITHIN 3`, which means it checks for new processes every 3 seconds. After Steam starts, it could take up to 3 seconds before the filter fires.

**The WMI objects are permanent:** Once created, they survive reboots. The `uninstall.ps1` script is the only way to remove them (short of manually deleting them with WMI tools).

---

## 8. Common Problems and What Causes Them

### Nothing happens when I double-click the .bat file

**Cause 1:** Windows Terminal is not installed.
**Fix:** Install Windows Terminal from the Microsoft Store.

**Cause 2:** A window flashes and disappears — PowerShell threw an error before the menu could draw.
**Fix:** Right-click the `.bat` file → "Run as Administrator" to see the error.

### The menu opens but shows wrong status

**Cause:** State detection uses Explorer, Power Plan, Timer Resolution, and Priority Separation as indicators. If you changed the power plan to something other than Balanced or Ultimate Performance externally, or if the Timer Resolution helper died unexpectedly, the status will show OFF even if other modules are in gaming state.

### Game mode won't turn on / "Error:" appears in red

**Common causes:**
1. **Tamper Protection is on** — Defender can't be modified. Turn it off in Windows Security settings, or disable the Defender module in Configure Game Mode.
2. **Ultimate Performance plan not found** — Use **Settings → Provision Ultimate Performance plan**.
3. **A module file is missing** — If any `_module.ps1` was deleted or renamed, the dot-source in `menu.ps1` will fail.

### The taskbar/desktop disappeared and didn't come back

**Cause:** Something interrupted the script while Explorer was killed.
**Fix:** Press `Ctrl+Shift+Esc` to open Task Manager → "Run new task" → type `explorer` → Enter.

### Timer resolution doesn't seem to be working

**Cause:** On Windows 11 and post-2004 Windows 10, timer resolution is scoped per-process. The resolution set by the helper only affects the helper process itself. Games and other applications do not inherit it unless they also call `NtSetTimerResolution` themselves.

This is a Windows design decision introduced in the 2004 update. There is no workaround at the OS level — each process must request its own resolution.

### Game Optimizer doesn't launch when Steam starts (after wmi-setup)

**Cause 1:** The folder was moved after running setup — the scheduled task points to the old path.
**Fix:** Run `game-mode-wmi-uninstall.ps1`, then `game-mode-wmi-setup.ps1` again with the correct path.

**Cause 2:** WMI service error. Check Event Viewer → `Applications and Services Logs → Microsoft → Windows → WMI-Activity → Operational`.

### After a crash, some settings are still at gaming values

**If you have the recovery task installed:** It ran at your next logon and already restored everything.

**If you don't have the recovery task:** Open the Game Optimizer normally. If it shows ON status, press Enter to disable. If Explorer is still dead: `Ctrl+Shift+Esc` → "Run new task" → `explorer`, then launch the optimizer.

---

## 9. Glossary of Terms

**Administrator / Elevated:** Running a program with the highest level of Windows privileges, allowing it to modify system settings, services, and the registry.

**BCD (Boot Configuration Data):** A database Windows reads at startup that controls boot options, including `disabledynamictick`. Edited with `bcdedit.exe`.

**Cmdlet:** A PowerShell command built into PowerShell itself. Names follow the `Verb-Noun` pattern, e.g., `Get-Service`, `Stop-Process`.

**Dot-sourcing:** Running a PowerShell script with a leading dot (`. "file.ps1"`) so that the functions and variables it defines become available in the current session.

**DWord:** A data type in the Windows Registry meaning a 32-bit unsigned integer (0 to 4,294,967,295).

**Dynamic Tick:** A Windows feature that allows the system timer interrupt rate to vary based on workload, saving power when idle. Disabling it (`disabledynamictick yes` in BCD) forces the timer to fire at its maximum constant rate, which improves timer precision at the cost of power usage. Requires a reboot.

**`finally` block:** A section of code in a `try/catch/finally` structure that is guaranteed to run regardless of whether the code succeeded or failed.

**GUID:** Globally Unique Identifier. A 128-bit number displayed as a hex string. Used to uniquely identify things like power plans.

**`HKLM`:** `HKEY_LOCAL_MACHINE` — the section of the Windows Registry that stores machine-wide settings.

**MSI (Message Signaled Interrupts):** A method for hardware (like GPUs) to signal the CPU using in-band messages over the PCIe bus rather than dedicated physical interrupt lines. Reduces interrupt latency and can improve GPU responsiveness. Enabled per-device in the registry; requires a reboot.

**NtSetTimerResolution:** A Windows NT internal function (in `ntdll.dll`) that sets the system timer resolution for the calling process. Takes a value in 100-nanosecond units: 5000 = 0.5ms, 10000 = 1ms.

**P/Invoke (Platform Invocation):** A mechanism that allows .NET code (and therefore PowerShell via `Add-Type`) to call functions in Windows DLLs that are not exposed as .NET APIs. Used here to call `NtSetTimerResolution` from the helper script.

**Polling:** Checking something repeatedly at a fixed interval instead of being notified when it changes.

**PowerShell Execution Policy:** A Windows setting that controls whether PowerShell scripts can run. The `.bat` file uses `-ExecutionPolicy Bypass` to override this for the one script invocation.

**Priority Separation:** A Windows scheduling parameter (`Win32PrioritySeparation`) that controls how much CPU time the foreground application receives versus background processes. Stored as a bitmask encoding quantum length, quantum type, and foreground boost level.

**Registry:** A hierarchical database built into Windows that stores configuration for the OS and applications. Organized into keys (like folders) and values (like files with data).

**Scheduled Task:** A Windows feature that runs programs at specified times or in response to triggers, under a specific user account.

**Sentinel file:** A file whose presence (not its contents) carries meaning. `_core\.game-mode-active` exists when game mode is on; its absence means game mode is off or was cleanly restored.

**Service:** A background process managed by Windows that can be started, stopped, and configured to run automatically on boot. Examples: SysMain, Windows Update.

**`$script:` scope:** A variable prefix that limits the variable's visibility to the current script file and the functions defined within it.

**Session 0:** An invisible Windows session used for background services running as SYSTEM. Applications launched in Session 0 do not appear on the interactive desktop.

**Tamper Protection:** A Windows Security feature that prevents external tools (including PowerShell) from changing Defender's settings. Must be turned off before this script can disable real-time protection. Cannot be toggled programmatically — only through the Windows Security UI.

**Timer Resolution:** The granularity of the Windows system timer — the minimum interval at which the OS can wake a sleeping thread or fire a timer. Default is ~15.625ms; this tool requests 0.5ms via a background helper process.

**UAC (User Account Control):** The Windows security feature that shows a permission popup before allowing elevated operations.

**WMI (Windows Management Instrumentation):** A Windows subsystem that provides a queryable interface to system information and events.

**WQL (WMI Query Language):** A SQL-like query language for querying WMI data.

**`wt.exe`:** The Windows Terminal executable.
