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

  - - - - - - - - - - - -
  STATUS: DISABLED
  - - - - - - - - - - - -

  [Press Enter] Enable Game Mode
  [Q] Quit
```

You press **Enter** once to turn on a collection of Windows optimizations that free up CPU and RAM for gaming. You press **Enter** again (or **Q**) to put everything back to normal. That's it from the user's perspective.

Under the hood, pressing Enter triggers five separate system changes at the same time:

| What gets changed | Gaming State | Normal State |
|---|---|---|
| Power Plan | Ultimate Performance | Balanced |
| Windows Explorer | Killed (taskbar disappears) | Running normally |
| Windows Defender | Real-time scanning OFF | Real-time scanning ON |
| SysMain (Superfetch) | Stopped | Running |
| Network Throttling | Disabled | Windows default |

The tool is designed with one important safety rule: **it always puts things back**. If you quit, if you close the window, or if the script crashes — it detects that game mode is active and restores all five settings before exiting.

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
│   ├── settings.ps1                 ← Settings screen: audio device switcher,
│   │                                   Configure Game Mode (per-module on/off toggles),
│   │                                   power plan provisioning, Tamper Protection
│   ├── recovery.ps1                 ← Crash recovery: restores settings at logon if
│   │                                   the script was killed while game mode was on
│   └── .game-mode-active            ← Sentinel file (created on enable, deleted on
│                                       disable; its presence means a crash recovery
│                                       may be needed — not tracked by git)
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
├── game-mode-wmi-setup.ps1          ← Optional: makes Game Mode auto-open when Steam starts
├── game-mode-wmi-uninstall.ps1      ← Optional: undoes what wmi-setup.ps1 did
├── game-mode-recovery-setup.ps1     ← Optional: registers logon recovery task for crash safety
└── game-mode-recovery-uninstall.ps1 ← Optional: removes the logon recovery task
```

Each `_module.ps1` file contains exactly two functions: one that **reads the current state** of that setting (is it on or off right now?), and one that **changes it**.

---

## 3. How a Toggle Actually Works (Step-by-Step)

Here is the full journey from double-click to your screen going back to normal, written as a sequence of events:

1. **You double-click `Game Optimizer.bat`.**

2. **The .bat file runs one line:** it opens Windows Terminal (`wt.exe`) and tells it to run `_core/menu.ps1` in a new PowerShell window, with the execution policy bypassed (meaning: Windows won't refuse to run the script just because it's unsigned).

3. **`menu.ps1` wakes up.** The first thing it does is check: *am I running as Administrator?* If not, it prints an error in red and exits immediately — you must re-launch the `.bat` file as Administrator manually. Without admin, most of the system changes would silently fail.

4. **The modules are loaded.** The script uses dot-sourcing (`. "path\to\file.ps1"`) to load all five module files and `_core\settings.ps1` into its own memory. Think of it like importing recipes into a cookbook — from this point on, `menu.ps1` can call the functions defined in those files. Loading `settings.ps1` also initializes the `$script:ModuleEnabled` table, which records which modules the user has configured to be active (all five are on by default).

5. **The menu loop begins.** The script enters a loop that keeps running until you press Q.

6. **On every loop iteration, the screen is cleared and redrawn.** Before drawing, it checks the state of whichever modules the user has enabled. For Explorer (if enabled): is it stopped? For Power Plan (if enabled): is it set to Ultimate Performance? If all enabled indicators agree game mode is on, the status is ON. The status badge and the button label update accordingly.

7. **The script waits for a keypress** using `[Console]::ReadKey($true)`. The `$true` means the keypress is not echoed to the screen — you press a key and nothing shows up, the screen just reacts.

8. **If you press Enter:**
   - If game mode is currently OFF → it calls the "enable" function for each module that is toggled on in Configure Game Mode, then writes a small sentinel file (`_core\.game-mode-active`) to disk to record that game mode is now active.
   - If game mode is currently ON → it calls the "disable" function for each enabled module, then deletes the sentinel file.
   - Either way, the loop immediately repeats, which clears and redraws the screen, updating the status.

9. **If you press Q:** the loop variable `$running` is set to `false`, the loop ends.

10. **The `finally` block runs.** This is a guaranteed cleanup step — it runs even if the script crashes mid-loop. It checks if game mode is on (Explorer stopped + power plan gaming), and if so, turns everything off with individual error handling per step so a failure in one doesn't skip the rest. It also deletes the sentinel file.

---

## 4. File-by-File Breakdown

---

### `Game Optimizer.bat`

```bat
@echo off
wt.exe powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0_core\menu.ps1"
```

**Line 1 — `@echo off`:** Tells the command prompt not to print each command to the screen as it runs. Without this, you'd see the raw commands flash on screen before the terminal opens.

**Line 2:** This is the entire logic of the file. Breaking it down piece by piece:

- `wt.exe` — launches Windows Terminal. If Windows Terminal is not installed, this line fails and nothing opens.
- `powershell.exe` — tells Windows Terminal to open a PowerShell session.
- `-NoProfile` — tells PowerShell not to load your personal profile script (which might contain settings or customizations that could interfere).
- `-ExecutionPolicy Bypass` — overrides Windows' default restriction on running PowerShell scripts. Without this, Windows might refuse to run an unsigned `.ps1` file.
- `-File "%~dp0_core\menu.ps1"` — the script file to run. `%~dp0` is a special .bat variable that means "the folder where this .bat file lives." So this always finds `menu.ps1` relative to where the .bat file is, not from wherever you happened to double-click it.

**What can go wrong here:** If `wt.exe` (Windows Terminal) is not installed, nothing happens — the window flashes and closes. Solution: install Windows Terminal from the Microsoft Store.

---

### `_core/menu.ps1`

This is the main brain of the entire project. It has four sections.

#### Section 1 — Elevation Check (Lines 2–8)

```powershell
if (-not ([Security.Principal.WindowsPrincipal]...IsInRole(...Administrator))) {
    Write-Host "  This script must be run as Administrator." -ForegroundColor Red
    Read-Host '  Press Enter to close'
    exit
}
```

This checks whether the current process is running as Administrator. The method it uses is built into .NET and is the standard, reliable way to check on Windows.

- If you're NOT an admin: it prints an error in red, waits for you to press Enter, and exits. There is no automatic re-launch — you must right-click `Game Optimizer.bat` and choose "Run as administrator" (or use the Task Scheduler / WMI auto-launch, which requests elevation through the scheduled task's `RunLevel Highest` setting).
- If you ARE already an admin: it skips all of this and continues.

**Why this matters:** Every module that changes a system setting requires admin rights. Without this check, the modules would fail silently or throw confusing errors.

**Note — why auto-elevation was removed:** An earlier version re-launched `powershell.exe` with `-Verb RunAs` to trigger a UAC prompt automatically. This worked but always opened a plain `conhost.exe` window instead of Windows Terminal. A subsequent attempt to elevate via `wt.exe -Verb RunAs` caused an infinite UAC loop on some systems (each relaunched window would fail the elevation check and spawn another). Removing auto-elevation sidesteps both problems cleanly.

#### Section 2 — Module Loading

```powershell
$root = Split-Path (Split-Path $PSCommandPath -Parent) -Parent
. "$root\Explorer\_module.ps1"
. "$root\Power Plan\_module.ps1"
...
. "$root\_core\settings.ps1"
```

`$PSCommandPath` is a built-in variable that contains the full path to the currently running script file. `Split-Path ... -Parent` takes that path and strips off the last component (like going "up" one folder).

Since `menu.ps1` is in `_core\`, one `Split-Path` gives us `_core\` and the second gives us the project root. That root path is stored in `$root`.

The `. "$root\Explorer\_module.ps1"` lines use **dot-sourcing**. The leading dot means: run this file and bring everything it defines into the current scope. Without the dot, the functions defined inside those files would be invisible to `menu.ps1`.

`settings.ps1` is dot-sourced here at startup (not lazily on demand) so that the `$script:ModuleEnabled` table it defines is available immediately — before the first toggle can occur.

**What can go wrong:** If any module file is missing or has a typo in it, the dot-source fails and the entire script crashes before the menu even draws. The error will say something like "file not found" or show a syntax error from the broken module.

#### Section 3 — Helper Functions (Lines 24–43)

These two functions (`Get-ArtColor` and `Write-Art`) exist purely to draw the ASCII art logo in two colors. They are cosmetic only — they do not affect any system setting.

- `Get-ArtColor` takes a single character and returns either `'DarkGray'` or `'White'`. Box-drawing characters (the lines that make up the logo frame, like `║`, `╗`, `░`) are dark gray. Everything else is white.
- `Write-Art` takes a line of text, splits it into segments of the same color, and prints each segment in the right color using `Write-Host`. The `-NoNewline` flag means it doesn't add a line break between segments — they're printed right next to each other on the same line.

#### Section 4 — The Menu Loop (Lines 47–125)

This is the core of the script. It runs inside a `try/catch/finally` block.

```powershell
$running = $true
try {
    while ($running) {
        [Console]::Clear()
        $on = ((Get-ExplorerState) -eq 'Stopped') -and ((Get-PowerPlanState) -eq 'Ultimate Performance')
        ...
    }
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Read-Host '  Press Enter to close'
} finally {
    # restore everything if game mode is on
}
```

**The state detection:** Explorer and Power Plan are used as the reliable visible indicators of game mode state. Defender, SysMain, and Network Throttling are treated as "side effects" — they get toggled along with the others, but the script doesn't check their state to decide whether game mode is "on."

The check is conditional on what the user has enabled in Configure Game Mode:

```powershell
$indicators = @()
if ($script:ModuleEnabled['Explorer'])   { $indicators += (Get-ExplorerState) -eq 'Stopped' }
if ($script:ModuleEnabled['Power Plan']) { $indicators += (Get-PowerPlanState) -eq 'Ultimate Performance' }
$on = $indicators.Count -gt 0 -and ($indicators -notcontains $false)
```

All enabled indicators must agree that game mode is on. If both Explorer and Power Plan are disabled in Configure Game Mode, `$indicators` is empty and the menu always shows DISABLED.

**The keypress capture:**
```powershell
$key = [Console]::ReadKey($true)
```
This waits indefinitely for exactly one key. `$true` suppresses the echo. The result is a .NET object with two useful properties:
- `$key.Key` — the key name (e.g., `Enter`, `Escape`, `UpArrow`)
- `$key.KeyChar` — the character typed (e.g., `'q'`, `'Q'`, `'1'`)

**The toggle logic:**

```powershell
if ($key.Key -eq [ConsoleKey]::Enter) {
    if (-not $on) {
        if ($script:ModuleEnabled['Explorer'])           { Set-Explorer $true }
        if ($script:ModuleEnabled['Power Plan'])         { Set-PowerPlan 'Ultimate' }
        if ($script:ModuleEnabled['Defender'])           { Set-Defender $true }
        if ($script:ModuleEnabled['SysMain'])            { Set-SysMain $true }
        if ($script:ModuleEnabled['Network Throttling']) { Set-NetworkThrottle $true }
        Set-Content $sentinelPath -Value '' -Force
    } else {
        if ($script:ModuleEnabled['Explorer'])           { Set-Explorer $false }
        if ($script:ModuleEnabled['Power Plan'])         { Set-PowerPlan 'Balanced' }
        if ($script:ModuleEnabled['Defender'])           { Set-Defender $false }
        if ($script:ModuleEnabled['SysMain'])            { Set-SysMain $false }
        if ($script:ModuleEnabled['Network Throttling']) { Set-NetworkThrottle $false }
        Remove-Item $sentinelPath -Force -ErrorAction SilentlyContinue
    }
}
```

Each `Set-*` function is defined in its corresponding module and is only called if that module is enabled in `$script:ModuleEnabled`. They're called in sequence — the script waits for each one to finish before calling the next.

`$sentinelPath` points to `_core\.game-mode-active`. Writing it after the five enable calls (and deleting it after the five disable calls) creates a durable record on disk of whether game mode is active. This survives a process kill or machine crash — unlike an in-memory variable, which vanishes when the process dies.

**The `catch` block:** If anything in the `try` block throws an unexpected error, execution jumps here. The error message is printed in red and the window waits for Enter before closing, so you can read the error.

**The `finally` block:** This block runs no matter what — whether the loop ended normally (Q was pressed), an error was caught, or even if PowerShell is in the middle of shutting down (e.g., terminal window closed). It checks if game mode is currently on, and if so restores all five settings:

```powershell
finally {
    $finalChecks = @()
    if ($script:ModuleEnabled['Explorer'])   { $finalChecks += (Get-ExplorerState) -eq 'Stopped' }
    if ($script:ModuleEnabled['Power Plan']) { $finalChecks += (Get-PowerPlanState) -eq 'Ultimate Performance' }
    $isOn = $finalChecks.Count -gt 0 -and ($finalChecks -notcontains $false)
    if ($isOn) {
        if ($script:ModuleEnabled['Explorer'])           { try { Set-Explorer $false }          catch {} }
        if ($script:ModuleEnabled['Power Plan'])         { try { Set-PowerPlan 'Balanced' }     catch {} }
        if ($script:ModuleEnabled['Defender'])           { try { Set-Defender $false }          catch {} }
        if ($script:ModuleEnabled['SysMain'])            { try { Set-SysMain $false }           catch {} }
        if ($script:ModuleEnabled['Network Throttling']) { try { Set-NetworkThrottle $false }   catch {} }
    }
    Remove-Item $sentinelPath -Force -ErrorAction SilentlyContinue
}
```

Each cleanup call is wrapped in its own `try/catch` so a failure in one step (e.g. Defender blocked by Tamper Protection) does not cause the remaining steps to be skipped. The sentinel is deleted at the end regardless of whether `$isOn` was true — if game mode was already off there's nothing to delete, and the `-ErrorAction SilentlyContinue` makes that a no-op.

---

### `_core/settings.ps1`

This file has two responsibilities: it defines the per-module configuration table, and it provides all the settings screens reachable via `[S]` in the main menu.

#### `$script:ModuleEnabled`

```powershell
$script:ModuleEnabled = [ordered]@{
    Explorer            = $true
    'Power Plan'        = $true
    Defender            = $true
    SysMain             = $true
    'Network Throttling' = $true
}
```

This ordered hashtable is the source of truth for which modules participate in a game mode toggle. It is initialized when `settings.ps1` is dot-sourced at startup (all five enabled by default) and lives in `$script:` scope, meaning it persists for the entire session — changes made in Configure Game Mode are remembered until the script exits.

`menu.ps1` reads this table on every toggle and every state-detection pass. `settings.ps1` writes to it when the user presses `[T]` on a module's config screen.

#### `Show-ConfigureGameMode`

Displays a numbered list of all five modules with their current ON/OFF status. Pressing a number opens that module's individual config screen (`Show-ModuleConfig`). The ON/OFF colors match the main menu: green for on, red for off.

#### `Show-ModuleConfig`

A generic screen that handles one module at a time. It shows:
- The module name
- "Included in Game Mode: Enabled / Disabled" in green or red
- A short description of what the module does
- `[T]` to toggle the module's entry in `$script:ModuleEnabled`
- `[B]` to go back

The screen redraws immediately on toggle so the status updates in place.

#### `Show-Settings`

The top-level settings screen. Shows:
- `[1] Audio Device` — if AudioDeviceCmdlets is installed
- `[C] Configure Game Mode` — always visible
- `[B] Back`
- Below the menu: yellow warning prompts for any missing prerequisites (AudioDeviceCmdlets, Ultimate Performance plan, Tamper Protection)

#### `Show-AudioDevice`

Lists all playback audio devices. The currently active device is highlighted in green. Pressing a number switches to that device using `Set-AudioDevice` from the AudioDeviceCmdlets module.

#### `Show-TamperProtection`

Opens the Windows Security threat settings page automatically, then polls `Get-MpComputerStatus` every 500ms. The status line updates live as Tamper Protection is toggled in the UI. Pressing `[B]` returns to Settings — the screen never exits on its own.

---

### `Explorer/_module.ps1`

This module manages Windows Explorer — the process that runs your desktop, taskbar, and file manager windows.

#### `Get-ExplorerState`

```powershell
function Get-ExplorerState {
    if (Get-Process explorer -ErrorAction SilentlyContinue) { 'Running' } else { 'Stopped' }
}
```

`Get-Process explorer` looks for a running process named `explorer`. If it finds one, the function returns the string `'Running'`. If it doesn't find one (which happens without an error — it just returns nothing), the `if` condition is falsy and it returns `'Stopped'`.

`-ErrorAction SilentlyContinue` tells PowerShell: if this command would normally produce an error, swallow it silently. Without this, PowerShell would print a red error message when Explorer isn't running.

#### `Set-Explorer`

```powershell
function Set-Explorer([bool]$stop) {
    if ($stop) {
        if (Get-Process explorer -ErrorAction SilentlyContinue) {
            & taskkill /f /im explorer.exe | Out-Null
            while (Get-Process explorer -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 100 }
        }
    } else {
        Start-Process explorer
    }
}
```

The parameter `[bool]$stop` is a true/false value. `$true` means "kill Explorer," `$false` means "start Explorer."

**Killing Explorer — why `taskkill` instead of `Stop-Process`:**

Windows has a built-in self-healing behavior for Explorer: if it dies, Windows automatically restarts it. `Stop-Process` kills processes one at a time, and it's slow enough that Windows can restart Explorer between kills — you end up in a loop where it keeps coming back. `taskkill /f /im explorer.exe` kills all instances simultaneously and wins that race.

- `/f` means "force" — don't wait for the process to close gracefully, just terminate it.
- `/im explorer.exe` means "by image name" — target any process with this filename.
- `| Out-Null` discards the output text that `taskkill` normally prints.

**The polling loop:**
```powershell
while (Get-Process explorer -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 100 }
```
After telling `taskkill` to kill Explorer, the script waits in a loop, checking every 100 milliseconds (0.1 seconds), until Explorer is truly gone. This matters because the menu checks the state immediately after this function returns — if we returned too early while Explorer was still dying, the menu would show the wrong state.

**Starting Explorer:**
```powershell
Start-Process explorer
```
Launching `explorer` with no arguments tells Windows to start the full shell — taskbar, desktop, and all. It's the normal way Explorer re-initializes itself.

---

### `Power Plan/_module.ps1`

This module controls which Windows power plan is active.

```powershell
$script:UltimatePerfGuid = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
$script:BalancedGuid     = '381b4222-f694-41f0-9685-ff5bb260df2e'
```

Every Windows power plan has a GUID — a globally unique identifier, which is a string of letters and numbers in a specific format. These two GUIDs are fixed by Microsoft and are the same on every Windows installation.

- `$script:` prefix means these variables are scoped to the module (the "script" scope). They're accessible within the module's functions but don't leak into the global namespace.

#### `Get-PowerPlanState`

```powershell
function Get-PowerPlanState {
    $active = & powercfg /getactivescheme
    if ($active -match $script:UltimatePerfGuid) { 'Ultimate Performance' }
    elseif ($active -match $script:BalancedGuid)  { 'Balanced' }
    else { 'Other' }
}
```

`powercfg /getactivescheme` is a Windows command-line tool. Its output looks like:
```
Power Scheme GUID: e9a42b02-d5df-448d-aa00-03f14749eb61  (Ultimate Performance)
```

The `-match` operator is a regex (pattern) comparison. It checks whether the output string contains the GUID anywhere in it. If neither known GUID is found, the function returns `'Other'` — meaning some third power plan is active (like High Performance, or a custom one).

#### `Set-PowerPlan`

```powershell
function Set-PowerPlan([string]$plan) {
    if ($plan -eq 'Ultimate') {
        & powercfg /setactive $script:UltimatePerfGuid
    } else {
        & powercfg /setactive $script:BalancedGuid
    }
}
```

`powercfg /setactive <GUID>` activates the power plan with that GUID. The change takes effect immediately.

**What can go wrong:** If the Ultimate Performance plan has never been activated on this machine (it's hidden by default on some Windows editions), the GUID exists but the plan might not be in the active list. You'd need to unhide it first with: `powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61`

---

### `Defender/_module.ps1`

This module toggles Windows Defender's real-time protection.

#### `Get-DefenderState`

```powershell
function Get-DefenderState {
    if ((Get-MpComputerStatus).RealTimeProtectionEnabled) { 'Enabled' } else { 'Disabled' }
}
```

`Get-MpComputerStatus` is a PowerShell cmdlet that returns a rich object describing the current state of Windows Defender. One of its properties is `RealTimeProtectionEnabled` — a true/false value. The function reads that property and returns a human-readable string.

#### `Set-Defender`

```powershell
function Set-Defender([bool]$disable) {
    Set-MpPreference -DisableRealtimeMonitoring $disable
}
```

`Set-MpPreference` is the standard cmdlet for changing Defender settings. The parameter name is `-DisableRealtimeMonitoring`, which is a boolean.

**Important — the parameter naming is inverted:** The function's parameter is called `$disable`. When game mode turns ON, it calls `Set-Defender $true` — meaning `$disable = $true` — which passes `$true` to `-DisableRealtimeMonitoring`, which disables protection. When game mode turns OFF, it calls `Set-Defender $false`, restoring protection.

**What can go wrong:** On Windows 11, Microsoft introduced Tamper Protection, which can block third-party changes to Defender settings, including this script. If Tamper Protection is enabled, `Set-MpPreference` will fail silently or throw an error. To allow this script to work, Tamper Protection must be turned off in Windows Security → Virus & Threat Protection → Manage Settings.

**Why the script can't automate this for you:** Tamper Protection is deliberately designed so that no script or program can toggle it — not even a PowerShell command running as Administrator. Microsoft blocks `Set-MpPreference` from touching it entirely. The only way to change it is through the Windows Security UI, where a human has to click the toggle. This is a security boundary Windows enforces by design, not a limitation of this script. That is also why the script does not re-enable Tamper Protection when game mode is disabled — it simply has no way to do so.

---

### `SysMain/_module.ps1`

SysMain is a Windows service previously known as "Superfetch." It pre-loads frequently used applications into RAM to make them start faster. During gaming, this background RAM activity can compete with the game.

#### `Get-SysMainState`

```powershell
function Get-SysMainState {
    if ((Get-Service SysMain).Status -eq 'Stopped') { 'Stopped' } else { 'Running' }
}
```

`Get-Service SysMain` fetches the Windows service object for SysMain. The `.Status` property will be one of: `Running`, `Stopped`, `StartPending`, `StopPending`, etc. This function simplifies that to either `'Stopped'` or `'Running'`.

#### `Set-SysMain`

```powershell
function Set-SysMain([bool]$stop) {
    if ($stop) { Stop-Service SysMain -Force } else { Start-Service SysMain }
}
```

`Stop-Service SysMain -Force` tells Windows to stop the SysMain service. `-Force` also stops any dependent services (services that rely on SysMain). Without `-Force`, the command might fail if something depends on SysMain.

`Start-Service SysMain` starts it again.

**Note:** Stopping a service does not uninstall it or change its startup type. When Windows reboots, SysMain will start up normally again (unless you've separately disabled it). The stop is only for the current session.

---

### `Network Throttling/_module.ps1`

This module edits two Windows Registry values that control how aggressively the OS throttles network traffic in the background.

```powershell
$script:TcpPath     = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
$script:ProfilePath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
```

These are paths in the Windows Registry — a database where Windows stores system configuration. `HKLM` stands for `HKEY_LOCAL_MACHINE`, meaning these settings apply to the whole machine, not just the current user.

#### `Get-NetworkThrottleState`

```powershell
function Get-NetworkThrottleState {
    $val = (Get-ItemProperty $script:TcpPath -Name NetworkThrottlingIndex -ErrorAction SilentlyContinue).NetworkThrottlingIndex
    if ($val -eq 0xFFFFFFFF) { 'Gaming' } else { 'Default' }
}
```

`Get-ItemProperty` reads registry values. It fetches the `NetworkThrottlingIndex` value from the TCP/IP parameters key. `0xFFFFFFFF` is a hexadecimal number (4294967295 in decimal) that tells Windows to disable network throttling entirely. If that value is found, game mode is considered active for this setting.

#### `Set-NetworkThrottle`

```powershell
function Set-NetworkThrottle([bool]$gaming) {
    if ($gaming) {
        Set-ItemProperty $script:TcpPath     -Name NetworkThrottlingIndex -Value 0xFFFFFFFF -Type DWord
        Set-ItemProperty $script:ProfilePath -Name SystemResponsiveness   -Value 0          -Type DWord
    } else {
        Set-ItemProperty $script:TcpPath     -Name NetworkThrottlingIndex -Value 10         -Type DWord
        Set-ItemProperty $script:ProfilePath -Name SystemResponsiveness   -Value 20         -Type DWord
    }
}
```

This sets two registry values:

**`NetworkThrottlingIndex`** (in TCP/IP Parameters):
- Gaming: `0xFFFFFFFF` — disables all network throttling. Windows normally throttles background network traffic to protect real-time applications, but setting this to max removes that cap.
- Default: `10` — the Windows-recommended default value.

**`SystemResponsiveness`** (in Multimedia SystemProfile):
- Gaming: `0` — tells Windows to dedicate maximum resources to multimedia/gaming tasks with zero background allocation.
- Default: `20` — Windows reserves 20% of CPU time for background tasks.

`-Type DWord` specifies the data type of the registry value. DWord = 32-bit integer. This must match the existing type or the write may fail.

**What can go wrong:** Registry edits require Administrator rights (already ensured by the elevation check). If the registry path doesn't exist (unusual, but possible on certain stripped-down Windows editions), the `Set-ItemProperty` call will throw an error.

---

### `game-mode-wmi-setup.ps1`

This is an optional, one-time setup script. You only run it once. Its job is to make the Game Optimizer launch automatically every time Steam starts, without you having to do anything.

#### Why it's complicated

Automatically launching a GUI app when another process starts is trickier than it sounds on Windows. The naive approach — "watch for steam.exe to start, then run the .bat file" — fails because:

> WMI event consumers (background watchers) run as the SYSTEM account in **Session 0**, which is an invisible background session. Any window opened from there never appears on your screen.

The solution is a two-part chain:
1. **WMI subscription** — watches for Steam to start (runs as SYSTEM in background)
2. **Scheduled Task** — launches the Game Optimizer in your interactive session (appears on screen)

The WMI subscription fires when Steam starts, but instead of opening the terminal directly, it just pokes the Scheduled Task: "hey, run now." The Scheduled Task is configured to run as your normal logged-in user, so its window appears on your desktop.

#### The three WMI objects created

**1. Event Filter (`SteamGameModeFilter`):**
```powershell
Query = "SELECT * FROM __InstanceCreationEvent WITHIN 3 " +
        "WHERE TargetInstance ISA 'Win32_Process' " +
        "AND TargetInstance.Name = 'steam.exe'"
```
This is a WQL (Windows Query Language) query — like SQL but for Windows system events. It says: "Every 3 seconds, check if any new process has been created. If that process is named `steam.exe`, fire."

- `__InstanceCreationEvent` — fires when a WMI object (like a process) is created
- `WITHIN 3` — poll interval in seconds (not truly real-time, checks every 3 seconds)
- `Win32_Process` — the WMI class representing running processes
- `TargetInstance.Name = 'steam.exe'` — filter to only Steam

**2. Event Consumer (`GameModeConsumer`):**
```powershell
CommandLineTemplate = "schtasks.exe /run /tn `"LaunchGameMode`""
```
When the filter fires, the consumer runs this command: `schtasks /run /tn LaunchGameMode` — which tells Windows Task Scheduler to immediately run the `LaunchGameMode` task.

**3. Filter-to-Consumer Binding:**
This is the connection object that wires the filter to the consumer. Without the binding, the filter and consumer exist but don't know about each other.

#### The Scheduled Task

```powershell
$action    = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$gameModeRoot\Game Optimizer.bat`""
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
$settings  = New-ScheduledTaskSettingsSet `
                -AllowStartIfOnBatteries `
                -DontStopIfGoingOnBatteries `
                -MultipleInstances IgnoreNew
```

- **Action**: run `cmd.exe` with the `.bat` file as the argument — effectively double-clicking it programmatically.
- **Principal**: run as the currently logged-in user (`$env:USERNAME`), in an interactive session (not background). This is what makes the window appear on screen.
- **`MultipleInstances IgnoreNew`**: if Steam relaunches while the optimizer is already open, don't open a second window — ignore the second trigger.

---

### `game-mode-wmi-uninstall.ps1`

This script reverses everything that `game-mode-wmi-setup.ps1` did. It removes the three WMI objects and the scheduled task.

**Order matters:** The binding must be removed first. The binding holds references to both the filter and the consumer. If you try to delete the filter or consumer while the binding still exists, WMI may refuse because the object is still in use.

```powershell
# 1. Remove binding (it references the other two)
$binding = Get-WmiObject ... | Where-Object { $_.Filter -like "*$filterName*" }
if ($binding) { $binding | Remove-WmiObject }

# 2. Remove filter
$filter = Get-WmiObject -Class __EventFilter -Filter "Name='$filterName'"
if ($filter) { $filter | Remove-WmiObject }

# 3. Remove consumer
$consumer = Get-WmiObject -Class CommandLineEventConsumer -Filter "Name='$consumerName'"
if ($consumer) { $consumer | Remove-WmiObject }

# 4. Remove scheduled task
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}
```

Every removal step is wrapped in an `if` check — if the object isn't found (already removed, or never created), it prints a message and moves on instead of crashing. This makes the script safe to run multiple times.

---

### `_core/recovery.ps1`

This script is the counterpart to the `finally` block. Where `finally` handles the case where PowerShell is still running when something goes wrong, `recovery.ps1` handles the case where the process was killed outright — terminal force-closed, `taskkill` on PowerShell, or a hard machine crash — so `finally` never had a chance to run.

It is not run by the user directly. It is invoked automatically by the `GameModeRecovery` scheduled task at logon (see `game-mode-recovery-setup.ps1` below).

```powershell
$sentinelPath = "$root\_core\.game-mode-active"
if (-not (Test-Path $sentinelPath)) { exit 0 }

# ... dot-source all modules ...

if ((Get-ExplorerState) -ne 'Running') { try { Set-Explorer $false } catch {} }
try { Set-PowerPlan 'Balanced' }   catch {}
try { Set-Defender $false }        catch {}
try { Set-SysMain $false }         catch {}
try { Set-NetworkThrottle $false } catch {}

Remove-Item $sentinelPath -Force -ErrorAction SilentlyContinue
```

**The sentinel check:** The very first thing the script does is look for `_core\.game-mode-active`. If that file doesn't exist, game mode was properly disabled before the script exited and there is nothing to recover — the script exits immediately. This check is what makes the task safe to run at every logon without doing anything on normal sessions.

**The Explorer check:** When your machine reboots, Windows automatically relaunches Explorer as part of the login process. By the time the scheduled task fires, Explorer is almost certainly already running. Calling `Set-Explorer $false` (which starts Explorer) when it is already running would open a spare File Explorer window — not what we want. So the recovery script checks first: only start Explorer if it genuinely isn't running (which would only happen if recovery is triggered in the middle of a session rather than after a reboot).

**Per-step error handling:** Same pattern as the hardened `finally` block — each call is wrapped individually so a failure in one setting doesn't abandon the others.

---

### `game-mode-recovery-setup.ps1`

An optional, one-time setup script (like `game-mode-wmi-setup.ps1` for Steam). Run it once as Administrator to register the `GameModeRecovery` scheduled task.

```powershell
$action    = New-ScheduledTaskAction `
                -Execute   "powershell.exe" `
                -Argument  "-NoProfile -ExecutionPolicy Bypass -File `"...\recovery.ps1`""
$trigger   = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
```

Key points:

- **Trigger — At Logon:** The task fires every time you log in to Windows. If no sentinel file is present (normal case), `recovery.ps1` exits in milliseconds and you never notice it ran.
- **`RunLevel Highest`:** The task runs with full administrator privileges without requiring a UAC prompt, because the task was registered by an administrator. This is the same mechanism used by the `LaunchGameMode` task in the WMI setup.
- **`-ExecutionPolicy Bypass`:** Same reason as in `Game Optimizer.bat` — allows the unsigned script to run without a policy error.

---

### `game-mode-recovery-uninstall.ps1`

Removes the `GameModeRecovery` task registered by the setup script. Safe to run multiple times — if the task isn't found it prints a message and moves on.

---

## 5. What "Game Mode ON" Actually Does to Your PC

Here is what happens at the hardware and OS level when you press Enter to enable game mode.

### Power Plan → Ultimate Performance

This plan was designed by Microsoft for workstations. The key difference from Balanced:
- Disables CPU park states (keeps all CPU cores active, no lazy spin-down between tasks)
- Disables PCIe Active State Power Management (keeps the GPU link at full speed)
- Sets the processor minimum state to 100% (the CPU never downclocks)
- Eliminates timer coalescing (tiny delays Windows groups timers into batches — removed for lower latency)

**Net effect:** Higher, more consistent CPU clock speeds, lower interrupt latency. Costs more power / generates more heat.

### Explorer → Killed

Windows Explorer is not just a file browser. It runs:
- The taskbar
- The Start menu
- The desktop (including icons and wallpaper)
- The notification area (system tray)
- File Explorer windows

When it's killed, all of that disappears. Your screen may go black or show just a wallpaper with nothing on it. The game you're playing is unaffected — it runs in its own process.

**Why this helps:** Explorer continuously uses CPU and RAM in the background, polling for file changes, rendering the taskbar, and handling notifications. Removing it frees those resources.

**Important:** While Explorer is killed, the taskbar, Start menu, and file explorer are unavailable. You can still use Alt+Tab between running applications. When game mode is turned off, Explorer restarts and everything comes back.

### Windows Defender → Real-Time Protection Disabled

Real-time protection means: Defender is constantly scanning files as they are opened, created, or modified. This has a measurable CPU and disk I/O cost, especially during loading screens when games read many files quickly.

Disabling this does not permanently disable Defender, does not remove virus definitions, and does not affect scheduled scans. It only turns off the continuous on-access scanning while you're gaming.

**Risk:** During the time real-time protection is off, if you download or run something malicious, Defender will not stop it. This is a trade-off you're accepting for the duration of game mode.

### SysMain (Superfetch) → Stopped

Superfetch works by analyzing which applications you use most and pre-loading their files into RAM before you launch them, so they start faster. While you're gaming, this is counterproductive: it competes for RAM with the game itself and causes background disk I/O.

Stopping the service does not permanently disable it — on next reboot it starts again. It only stops it for the current session.

### Network Throttling → Disabled

Windows normally reserves a portion of CPU time for non-realtime network traffic, and it rate-limits background network activity to ensure audio and video playback remain smooth. Two registry keys control this:

- `NetworkThrottlingIndex = 0xFFFFFFFF` removes the limit on non-multimedia network packets
- `SystemResponsiveness = 0` tells Windows to give zero CPU share to background tasks, maximum to foreground/multimedia

This can reduce latency jitter in online games where Windows background traffic was occasionally competing with game packets.

---

## 6. The Auto-Restore Safety Net

There are two layers of protection that restore system settings when the script exits while game mode is active. They cover different failure scenarios.

### Layer 1 — The `finally` block (in-process cleanup)

A `finally` block in PowerShell runs in every exit scenario where the PowerShell process itself is still in control:
- Normal exit (Q pressed)
- An unhandled error inside the menu loop
- The terminal window closed with the X button (PowerShell gets a signal and runs `finally` before the host kills it)

It checks the two state indicators — Explorer stopped and power plan gaming — and if both are true it restores all five settings. Each call is wrapped individually so a failure in one step does not cause the others to be skipped.

**What `finally` cannot cover:** If the PowerShell process is killed with no warning (e.g. `taskkill /f`, a machine crash, or a power outage), Windows terminates it immediately with no opportunity to run any cleanup code.

### Layer 2 — Sentinel file + logon recovery task (crash/kill cleanup)

This layer covers the cases that `finally` cannot.

**The sentinel file (`_core\.game-mode-active`):**

When game mode is enabled, the script writes a small empty file to disk. When game mode is disabled — whether by the user pressing Enter, pressing Q, or by the `finally` block — the file is deleted. If the process is killed or the machine crashes while game mode is on, the file remains on disk after reboot.

The sentinel is the durable record that survives any termination scenario. It is not tracked by git (listed in `.gitignore`), so it only exists when game mode is actively on.

**The `GameModeRecovery` scheduled task (opt-in):**

If you have run `game-mode-recovery-setup.ps1`, a scheduled task fires at every logon. It runs `_core\recovery.ps1`, which:

1. Checks for the sentinel file. If not found → exits immediately (nothing to recover).
2. If found → restores all five settings with per-step error handling.
3. Deletes the sentinel.

The result: the next time you log in after a crash, your power plan is back to Balanced, Defender is re-enabled, SysMain is running, and network throttling is restored — automatically, before you even see your desktop.

**What each layer covers:**

| Scenario | `finally` runs? | Recovery task runs? |
|---|---|---|
| Q pressed (normal quit) | Yes | Sentinel deleted by `finally`, task does nothing |
| Terminal window X button | Yes (usually) | Sentinel deleted by `finally`, task does nothing |
| Terminal force-killed (`taskkill /f`) | No | Yes, at next logon |
| Machine crash / BSOD | No | Yes, at next logon |
| Power outage | No | Yes, at next logon |

Explorer is treated specially in the recovery task: since Windows auto-relaunches Explorer at logon, the task only calls `Set-Explorer` if Explorer is genuinely not running (which would only apply if recovery were triggered mid-session without a reboot).

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

**Why there's a 3-second delay:** The WMI filter uses `WITHIN 3`, which means it checks for new processes every 3 seconds. This is a polling interval, not a real-time notification. After Steam starts, it could take up to 3 seconds before the filter fires. In practice this is imperceptible.

**The WMI objects are permanent:** Once created, these objects survive reboots. They live in the WMI repository (`root\subscription` namespace) and are loaded by the WMI service on startup. The `uninstall.ps1` script is the only way to remove them (short of manually deleting them with WMI tools).

---

## 8. Common Problems and What Causes Them

### Nothing happens when I double-click the .bat file

**Cause 1:** Windows Terminal is not installed. The `.bat` file calls `wt.exe`, which only exists if Windows Terminal is installed.  
**Fix:** Install Windows Terminal from the Microsoft Store.

**Cause 2:** A window flashes and disappears. This usually means PowerShell threw an error before the menu could draw.  
**Fix:** Right-click the `.bat` file → "Run as Administrator" to see if an elevation error appears.

### The menu opens but shows wrong status

**Cause:** The state detection relies on exactly two checks — Explorer process status and power plan GUID. If you changed the power plan to something other than Balanced or Ultimate Performance, the script will see `'Other'` and report game mode as off even if Explorer is killed.

### Game mode won't turn on / "Error:" appears in red

**Common causes:**
1. **Tamper Protection is on** — Defender can't be modified. Turn it off in Windows Security settings first.
2. **Ultimate Performance plan not found** — The power plan GUID is not on this machine. Run `powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61` to add it.
3. **A module file is missing** — If any `_module.ps1` file was deleted or renamed, the dot-source in `menu.ps1` will fail.

### The taskbar/desktop disappeared and didn't come back

**Cause:** Something interrupted the script (crash, power event) while Explorer was killed.  
**Fix:** Press `Ctrl+Shift+Esc` to open Task Manager. Click "Run new task," type `explorer`, and press Enter. Explorer restarts immediately.

### Game Optimizer doesn't launch when Steam starts (after wmi-setup)

**Cause 1:** The WMI subscription was created for a different username or path. The setup script hardcodes your username and path at the time it was run. If you moved the game-mode folder or changed your Windows username, the scheduled task points to the wrong location.  
**Fix:** Run `game-mode-wmi-uninstall.ps1` to remove the old subscription, then move/rename as needed, then run `game-mode-wmi-setup.ps1` again.

**Cause 2:** The WMI service encountered an error. You can check the WMI event log in Event Viewer under `Applications and Services Logs → Microsoft → Windows → WMI-Activity → Operational`.

### After a crash, network feels different / slower (or power plan is wrong)

**Cause:** The `finally` block didn't run (hard crash, power loss, or force-kill), so some settings are still at gaming values.

**If you have the recovery task installed (`game-mode-recovery-setup.ps1`):** It ran at your next logon and already restored everything. The settings should be back to normal.

**If you don't have the recovery task:** Open the Game Optimizer normally, confirm it shows "ENABLED" status, then press Enter to disable it. All settings will be restored. If the Game Optimizer itself won't open (e.g. Explorer is still dead), press `Ctrl+Shift+Esc` to open Task Manager, click "Run new task," type `explorer`, and press Enter — then launch the optimizer normally.

---

## 9. Glossary of Terms

**Administrator / Elevated:** Running a program with the highest level of Windows privileges, allowing it to modify system settings, services, and the registry. The UAC (User Account Control) popup is Windows asking for your permission to elevate.

**Cmdlet:** A PowerShell command built into PowerShell itself (as opposed to an external program like `taskkill.exe`). Names follow the `Verb-Noun` pattern, e.g., `Get-Service`, `Stop-Process`.

**Dot-sourcing:** Running a PowerShell script with a leading dot (`. "file.ps1"`) so that the functions and variables it defines become available in the current session. Without the dot, those definitions disappear when the script finishes.

**DWord:** A data type in the Windows Registry meaning a 32-bit unsigned integer (a whole number from 0 to 4,294,967,295).

**`finally` block:** A section of code in a `try/catch/finally` structure that is guaranteed to run regardless of whether the code succeeded or failed. Used for cleanup.

**GUID:** Globally Unique Identifier. A 128-bit number displayed as a hex string like `e9a42b02-d5df-448d-aa00-03f14749eb61`. Used to uniquely identify things like power plans.

**`HKLM`:** `HKEY_LOCAL_MACHINE` — the section of the Windows Registry that stores machine-wide settings, as opposed to `HKCU` (current user only).

**Polling:** Checking something repeatedly at a fixed interval instead of being notified when it changes. The WMI filter uses polling (`WITHIN 3` = every 3 seconds).

**PowerShell Execution Policy:** A Windows setting that controls whether PowerShell scripts can run. Common values: `Restricted` (no scripts), `RemoteSigned` (local scripts OK), `Bypass` (everything allowed). The `.bat` file uses `-ExecutionPolicy Bypass` to override this just for the one script invocation.

**Registry:** A hierarchical database built into Windows that stores configuration for the OS and applications. Organized into keys (like folders) and values (like files with data in them).

**Scheduled Task:** A Windows feature (Task Scheduler) that can run programs at specified times or in response to triggers, under a specific user account.

**Service:** A background process managed by Windows that can be started, stopped, and configured to run automatically on boot. Examples: SysMain, Windows Update, Print Spooler.

**`$script:` scope:** A variable prefix that limits the variable's visibility to the current script file and the functions defined within it. Prevents accidental name collisions with variables in other scripts.

**Session 0:** An invisible Windows session used for background services running as SYSTEM. Applications launched in Session 0 do not appear on the interactive desktop — this is why WMI consumers can't open windows directly.

**Tamper Protection:** A Windows Security feature that prevents external tools (including PowerShell) from changing Defender's settings. Must be turned off before this script can disable real-time protection. It cannot be toggled programmatically — not even by a script running as Administrator. The only way to change it is through the Windows Security UI.

**UAC (User Account Control):** The Windows security feature that shows a "Do you want to allow this app to make changes to your device?" popup before allowing elevated operations.

**WMI (Windows Management Instrumentation):** A Windows subsystem that provides a queryable interface to system information and events. Programs can subscribe to WMI events (like "a process was created") and receive callbacks.

**WQL (WMI Query Language):** A SQL-like query language for querying WMI data. Used in the event filter to describe which process creation events should trigger the subscription.

**`wt.exe`:** The Windows Terminal executable. The `.bat` file uses this to open the optimizer in a proper modern terminal window rather than the older `cmd.exe` window.
