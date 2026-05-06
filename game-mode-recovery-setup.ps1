#Requires -RunAsAdministrator
#
# game-mode-recovery-setup.ps1
# Registers a logon-triggered scheduled task that restores system settings
# if the Game Optimizer exits unexpectedly while game mode is active.
# Reversal: run game-mode-recovery-uninstall.ps1

$gameModeRoot = "C:\Users\$env:USERNAME\Documents\Claude Projects\game-mode"
$taskName     = "GameModeRecovery"

$action    = New-ScheduledTaskAction `
                -Execute "powershell.exe" `
                -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$gameModeRoot\_core\recovery.ps1`""

$trigger   = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

$principal = New-ScheduledTaskPrincipal `
                -UserId    $env:USERNAME `
                -LogonType Interactive `
                -RunLevel  Highest

$settings  = New-ScheduledTaskSettingsSet `
                -AllowStartIfOnBatteries `
                -DontStopIfGoingOnBatteries `
                -ExecutionTimeLimit (New-TimeSpan -Minutes 2)

Register-ScheduledTask `
    -TaskName  $taskName `
    -Action    $action `
    -Trigger   $trigger `
    -Principal $principal `
    -Settings  $settings `
    -Force | Out-Null

Write-Host "Scheduled task '$taskName' registered."
Write-Host ""
Write-Host "Done. Game Mode settings will be restored automatically at next logon if the"
Write-Host "optimizer exits unexpectedly while game mode is active."
