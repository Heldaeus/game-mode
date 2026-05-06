#Requires -RunAsAdministrator
#
# game-mode-recovery-uninstall.ps1
# Reversal script for game-mode-recovery-setup.ps1
# Safe to run multiple times.

$taskName = "GameModeRecovery"

if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Scheduled task '$taskName' removed."
} else {
    Write-Host "Scheduled task '$taskName' not found (already removed or never created)."
}

Write-Host ""
Write-Host "Uninstall complete. Logon recovery will no longer run."
