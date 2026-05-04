function Get-DefenderState {
    if ((Get-MpComputerStatus).RealTimeProtectionEnabled) { 'Enabled' } else { 'Disabled' }
}

function Set-Defender([bool]$disable) {
    Set-MpPreference -DisableRealtimeMonitoring $disable
}
