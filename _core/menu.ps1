# ── Elevation ─────────────────────────────────────────────────────────────────
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $me = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
    try {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$me`"" -Verb RunAs -ErrorAction Stop
    } catch {
        Write-Host "Elevation failed: $_" -ForegroundColor Red
        Read-Host 'Press Enter to close'
    }
    exit
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ── Modules ───────────────────────────────────────────────────────────────────
$root = Split-Path (Split-Path $PSCommandPath -Parent) -Parent
. "$root\Explorer\_module.ps1"
. "$root\Power Plan\_module.ps1"
. "$root\Defender\_module.ps1"
. "$root\SysMain\_module.ps1"
. "$root\Network Throttling\_module.ps1"

# ── Menu loop ─────────────────────────────────────────────────────────────────

$running = $true

try {

while ($running) {
    [Console]::Clear()

    # Explorer + Power Plan are the reliable visible indicators of game state.
    # New modules (Defender, SysMain, Network) run as side effects but don't gate the toggle.
    $on = ((Get-ExplorerState) -eq 'Stopped') -and ((Get-PowerPlanState) -eq 'Ultimate Performance')
    $actionLabel = if ($on) { 'Disable Game Mode' } else { 'Enable Game Mode' }

    Write-Host "  ██████╗  █████╗ ███╗   ███╗███████╗"
    Write-Host " ██╔════╝ ██╔══██╗████╗ ████║██╔════╝"
    Write-Host " ██║  ███╗███████║██╔████╔██║█████╗  "
    Write-Host " ██║   ██║██╔══██║██║╚██╔╝██║██╔══╝  "
    Write-Host " ╚██████╔╝██║  ██║██║ ╚═╝ ██║███████╗"
    Write-Host "  ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝"
    Write-Host ""
    Write-Host " ███╗   ███╗ ██████╗ ██████╗ ███████╗"
    Write-Host " ████╗ ████║██╔═══██╗██╔══██╗██╔════╝"
    Write-Host " ██╔████╔██║██║   ██║██║  ██║█████╗  "
    Write-Host " ██║╚██╔╝██║██║   ██║██║  ██║██╔══╝  "
    Write-Host " ██║ ╚═╝ ██║╚██████╔╝██████╔╝███████╗"
    Write-Host " ╚═╝     ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝"
    Write-Host ""
    Write-Host ("  " + $actionLabel)
    Write-Host "  [Press Enter]"
    Write-Host ""
    Write-Host "  [Q] Quit"
    Write-Host ""

    # ReadKey captures a single keypress without echoing it or showing a prompt.
    $key = [Console]::ReadKey($true)

    if ($key.Key -eq [ConsoleKey]::Enter) {
        if (-not $on) {
            Set-Explorer $true
            Set-PowerPlan 'Ultimate'
            Set-Defender $true
            Set-SysMain $true
            Set-NetworkThrottle $true
        } else {
            Set-Explorer $false
            Set-PowerPlan 'Balanced'
            Set-Defender $false
            Set-SysMain $false
            Set-NetworkThrottle $false
        }
    } elseif ($key.KeyChar -eq 'q' -or $key.KeyChar -eq 'Q') {
        $running = $false
    }
}

} catch {
    Write-Host ""
    Write-Host "  Error: $_" -ForegroundColor Red
    Read-Host '  Press Enter to close'
} finally {
    $isOn = ((Get-ExplorerState) -eq 'Stopped') -and ((Get-PowerPlanState) -eq 'Ultimate Performance')
    if ($isOn) {
        Set-Explorer $false
        Set-PowerPlan 'Balanced'
        Set-Defender $false
        Set-SysMain $false
        Set-NetworkThrottle $false
    }
}