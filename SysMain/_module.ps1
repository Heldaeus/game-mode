function Get-SysMainState {
    if ((Get-Service SysMain).Status -eq 'Stopped') { 'Stopped' } else { 'Running' }
}

function Set-SysMain([bool]$stop) {
    if ($stop) { Stop-Service SysMain -Force } else { Start-Service SysMain }
}
