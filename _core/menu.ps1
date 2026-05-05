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

# ── Helpers ───────────────────────────────────────────────────────────────────
function Get-ArtColor ([char]$ch) {
    if ($ch -eq '░') { return 'DarkGray' }
    $cp = [int]$ch
    if ($cp -ge 0x2500 -and $cp -le 0x257F) { return 'DarkGray' }
    return 'White'
}

function Write-Art ([string]$line) {
    $seg = ''; $curColor = $null
    foreach ($ch in $line.ToCharArray()) {
        $color = Get-ArtColor $ch
        if ($color -ne $curColor) {
            if ($seg) { Write-Host $seg -NoNewline -ForegroundColor $curColor }
            $seg = ''; $curColor = $color
        }
        $seg += $ch
    }
    if ($seg) { Write-Host $seg -NoNewline -ForegroundColor $curColor }
    Write-Host ''
}

# ── Menu loop ─────────────────────────────────────────────────────────────────

$running = $true

try {

while ($running) {
    [Console]::Clear()

    # Explorer + Power Plan are the reliable visible indicators of game state.
    # New modules (Defender, SysMain, Network) run as side effects but don't gate the toggle.
    $on = ((Get-ExplorerState) -eq 'Stopped') -and ((Get-PowerPlanState) -eq 'Ultimate Performance')
    $settingsAlert = (-not [bool](Get-Module -ListAvailable -Name AudioDeviceCmdlets)) -or
                     (-not (Test-UltimatePerfAvailable)) -or
                     ((Get-MpComputerStatus).IsTamperProtected)
    $actionLabel = if ($on) { 'Disable Game Mode' } else { 'Enable Game Mode' }

    Write-Host ""
    Write-Art " ░██████╗░░█████╗░███╗░░░███╗███████╗"
    Write-Art " ██╔════╝░██╔══██╗████╗░████║██╔════╝"
    Write-Art " ██║░░██╗░███████║██╔████╔██║█████╗░░"
    Write-Art " ██║░░╚██╗██╔══██║██║╚██╔╝██║██╔══╝░░"
    Write-Art " ╚██████╔╝██║░░██║██║░╚═╝░██║███████╗"
    Write-Art " ░╚═════╝░╚═╝░░╚═╝╚═╝░░░░╚═╝╚══════╝"
    Write-Art " ███╗░░░███╗░█████╗░██████╗░███████╗"
    Write-Art " ████╗░████║██╔══██╗██╔══██╗██╔════╝"
    Write-Art " ██╔████╔██║██║░░██║██║░░██║█████╗░░"
    Write-Art " ██║╚██╔╝██║██║░░██║██║░░██║██╔══╝░░"
    Write-Art " ██║░╚═╝░██║╚█████╔╝██████╔╝███████╗"
    Write-Art " ╚═╝░░░░╚═╝░╚════╝░╚═════╝░╚══════╝"
    $statusLabel = if ($on) { 'ENABLED' } else { 'DISABLED' }
    $statusColor = if ($on) { 'Green' } else { 'Red' }
    $dash = ' ' + ('═' * 35)
    $statusText = 'STATUS: '
    $pad = [string]::new(' ', [Math]::Floor(($dash.Length - $statusText.Length - $statusLabel.Length) / 2))
    Write-Host ""
    Write-Host $dash -ForegroundColor DarkGray
    Write-Host ""
    Write-Host ($pad + $statusText) -NoNewline -ForegroundColor Gray
    Write-Host $statusLabel -ForegroundColor $statusColor
    Write-Host ""
    Write-Host $dash -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  " -NoNewline; Write-Host "[PRESS ENTER]" -NoNewline -ForegroundColor DarkGray; Write-Host " $actionLabel"
    Write-Host ""
    Write-Host "  " -NoNewline; Write-Host "[S]" -NoNewline -ForegroundColor DarkGray
    if ($settingsAlert) { Write-Host " Settings " -NoNewline; Write-Host "*" -ForegroundColor Yellow }
    else                 { Write-Host " Settings" }
    Write-Host "  " -NoNewline; Write-Host "[Q]" -NoNewline -ForegroundColor DarkGray; Write-Host " Quit"
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
    } elseif ($key.KeyChar -eq 's' -or $key.KeyChar -eq 'S') {
        . "$root\_core\settings.ps1"
        Show-Settings
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