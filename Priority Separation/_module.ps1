$script:PrioritySepRegPath    = 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'
$script:PrioritySepRegName    = 'Win32PrioritySeparation'
$script:PrioritySepGaming     = 0x26
$script:PrioritySepSavePath   = "$root\_core\.priority-sep-original"

function Get-PrioritySepState {
    $val = (Get-ItemProperty $script:PrioritySepRegPath -Name $script:PrioritySepRegName -ErrorAction SilentlyContinue).$script:PrioritySepRegName
    if ($val -eq $script:PrioritySepGaming) { 'Gaming' } else { 'Default' }
}

function Set-PrioritySep([bool]$gaming) {
    if ($gaming) {
        $current = (Get-ItemProperty $script:PrioritySepRegPath -Name $script:PrioritySepRegName -ErrorAction SilentlyContinue).$script:PrioritySepRegName
        if ($null -ne $current) { Set-Content $script:PrioritySepSavePath -Value $current -Force }
        Set-ItemProperty $script:PrioritySepRegPath -Name $script:PrioritySepRegName -Value $script:PrioritySepGaming -Type DWord
    } else {
        if (Test-Path $script:PrioritySepSavePath) {
            $orig = [int](Get-Content $script:PrioritySepSavePath -Raw -ErrorAction SilentlyContinue)
            Set-ItemProperty $script:PrioritySepRegPath -Name $script:PrioritySepRegName -Value $orig -Type DWord
            Remove-Item $script:PrioritySepSavePath -Force -ErrorAction SilentlyContinue
        }
    }
}
