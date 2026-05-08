# ── Elevation ─────────────────────────────────────────────────────────────────
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host ""
    Write-Host "  This script must be run as Administrator." -ForegroundColor Red
    Write-Host ""
    Read-Host '  Press Enter to close'
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
. "$root\Timer Resolution\_module.ps1"
. "$root\_core\settings.ps1"

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

$running      = $true
$sentinelPath = "$root\_core\.game-mode-active"

function Get-SettingsAlert {
    (-not [bool](Get-Module -ListAvailable -Name AudioDeviceCmdlets)) -or
    (-not (Test-UltimatePerfAvailable)) -or
    ((Get-MpComputerStatus).IsTamperProtected)
}

try {

while ($running) {
    [Console]::Clear()

    $settingsAlert = Get-SettingsAlert

    # Check only enabled modules; all must agree game mode is on.
    $indicators = @()
    if ($script:ModuleEnabled['Explorer'])          { $indicators += (Get-ExplorerState) -eq 'Stopped' }
    if ($script:ModuleEnabled['Power Plan'])        { $indicators += (Get-PowerPlanState) -eq 'Ultimate Performance' }
    if ($script:ModuleEnabled['Timer Resolution'])  { $indicators += (Get-TimerResState) -eq 'Active' }
    $on = $indicators.Count -gt 0 -and ($indicators -notcontains $false)
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
    $statusText  = 'STATUS: '
    $innerWidth  = 33
    $leftPad     = [Math]::Floor(($innerWidth - $statusText.Length - $statusLabel.Length) / 2)
    $rightPad    = $innerWidth - $statusText.Length - $statusLabel.Length - $leftPad
    $emptyRow    = ' ║' + (' ' * $innerWidth) + '║'

    Write-Host ""
    Write-Host (' ╔' + ('═' * $innerWidth) + '╗') -ForegroundColor DarkGray
    Write-Host $emptyRow -ForegroundColor DarkGray
    Write-Host ' ║' -NoNewline -ForegroundColor DarkGray
    Write-Host (' ' * $leftPad + $statusText) -NoNewline -ForegroundColor Gray
    Write-Host ($statusLabel + ' ' * $rightPad) -NoNewline -ForegroundColor $statusColor
    Write-Host '║' -ForegroundColor DarkGray
    Write-Host $emptyRow -ForegroundColor DarkGray
    Write-Host (' ╚' + ('═' * $innerWidth) + '╝') -ForegroundColor DarkGray
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
            if ($script:ModuleEnabled['Explorer'])             { Set-Explorer $true }
            if ($script:ModuleEnabled['Power Plan'])           { Set-PowerPlan 'Ultimate' }
            if ($script:ModuleEnabled['Defender'])             { Set-Defender $true }
            if ($script:ModuleEnabled['SysMain'])              { Set-SysMain $true }
            if ($script:ModuleEnabled['Network Throttling'])   { Set-NetworkThrottle $true }
            if ($script:ModuleEnabled['Timer Resolution'])     { Set-TimerRes $true }
            Set-Content $sentinelPath -Value '' -Force
        } else {
            if ($script:ModuleEnabled['Explorer'])             { Set-Explorer $false }
            if ($script:ModuleEnabled['Power Plan'])           { Set-PowerPlan 'Balanced' }
            if ($script:ModuleEnabled['Defender'])             { Set-Defender $false }
            if ($script:ModuleEnabled['SysMain'])              { Set-SysMain $false }
            if ($script:ModuleEnabled['Network Throttling'])   { Set-NetworkThrottle $false }
            if ($script:ModuleEnabled['Timer Resolution'])     { Set-TimerRes $false }
            Remove-Item $sentinelPath -Force -ErrorAction SilentlyContinue
        }
    } elseif ($key.KeyChar -eq 's' -or $key.KeyChar -eq 'S') {
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
    $finalChecks = @()
    if ($script:ModuleEnabled['Explorer'])          { $finalChecks += (Get-ExplorerState) -eq 'Stopped' }
    if ($script:ModuleEnabled['Power Plan'])        { $finalChecks += (Get-PowerPlanState) -eq 'Ultimate Performance' }
    if ($script:ModuleEnabled['Timer Resolution'])  { $finalChecks += (Get-TimerResState) -eq 'Active' }
    $isOn = $finalChecks.Count -gt 0 -and ($finalChecks -notcontains $false)
    if ($isOn) {
        if ($script:ModuleEnabled['Explorer'])             { try { Set-Explorer $false }          catch {} }
        if ($script:ModuleEnabled['Power Plan'])           { try { Set-PowerPlan 'Balanced' }     catch {} }
        if ($script:ModuleEnabled['Defender'])             { try { Set-Defender $false }          catch {} }
        if ($script:ModuleEnabled['SysMain'])              { try { Set-SysMain $false }           catch {} }
        if ($script:ModuleEnabled['Network Throttling'])   { try { Set-NetworkThrottle $false }   catch {} }
        if ($script:ModuleEnabled['Timer Resolution'])     { try { Set-TimerRes $false }          catch {} }
    }
    Remove-Item $sentinelPath -Force -ErrorAction SilentlyContinue
}