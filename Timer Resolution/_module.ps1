$script:TimerResPidPath = "$root\_core\.timer-res-pid"

function Get-TimerResState {
    if (-not (Test-Path $script:TimerResPidPath)) { return 'Inactive' }
    $helperPid = [int](Get-Content $script:TimerResPidPath -Raw -ErrorAction SilentlyContinue)
    if ($helperPid -and (Get-Process -Id $helperPid -ErrorAction SilentlyContinue)) { 'Active' } else { 'Inactive' }
}

function Set-TimerRes([bool]$enable) {
    if ($enable) {
        $proc = Start-Process powershell.exe `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$root\Timer Resolution\_helper.ps1`"" `
            -WindowStyle Hidden `
            -PassThru
        Set-Content $script:TimerResPidPath -Value $proc.Id -Force
    } else {
        if (Test-Path $script:TimerResPidPath) {
            $helperPid = [int](Get-Content $script:TimerResPidPath -Raw -ErrorAction SilentlyContinue)
            if ($helperPid) { Stop-Process -Id $helperPid -Force -ErrorAction SilentlyContinue }
            Remove-Item $script:TimerResPidPath -Force -ErrorAction SilentlyContinue
        }
    }
}
