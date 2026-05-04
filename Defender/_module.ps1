function Get-DefenderState {
    if ((Get-MpComputerStatus).RealTimeProtectionEnabled) { 'Enabled' } else { 'Disabled' }
}

function Set-Defender([bool]$disable) {
    try {
        Set-MpPreference -DisableRealtimeMonitoring $disable -ErrorAction Stop
    } catch {
        # Tamper Protection or group policy is blocking this — skip silently
    }
}
