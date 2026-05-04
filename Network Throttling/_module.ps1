$script:TcpPath     = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
$script:ProfilePath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'

function Get-NetworkThrottleState {
    $val = (Get-ItemProperty $script:TcpPath -Name NetworkThrottlingIndex -ErrorAction SilentlyContinue).NetworkThrottlingIndex
    if ($val -eq 0xFFFFFFFF) { 'Gaming' } else { 'Default' }
}

function Set-NetworkThrottle([bool]$gaming) {
    if ($gaming) {
        Set-ItemProperty $script:TcpPath     -Name NetworkThrottlingIndex -Value 0xFFFFFFFF -Type DWord
        Set-ItemProperty $script:ProfilePath -Name SystemResponsiveness   -Value 0          -Type DWord
    } else {
        Set-ItemProperty $script:TcpPath     -Name NetworkThrottlingIndex -Value 10         -Type DWord
        Set-ItemProperty $script:ProfilePath -Name SystemResponsiveness   -Value 20         -Type DWord
    }
}
