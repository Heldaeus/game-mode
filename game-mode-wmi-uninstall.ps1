#Requires -RunAsAdministrator
#
# game-mode-wmi-uninstall.ps1
# Reversal script for game-mode-wmi-setup.ps1
#
# Removes the WMI subscription objects (binding, filter, consumer)
# and the scheduled task created by the setup script.
# Safe to run multiple times -- each removal is conditional.

$taskName      = "LaunchGameMode"
$filterName    = "SteamGameModeFilter"
$consumerName  = "GameModeConsumer"

# Remove binding first -- it references the filter and consumer,
# so it must be deleted before those objects can be cleanly removed.
$binding = Get-CimInstance -Namespace root/subscription -ClassName __FilterToConsumerBinding |
           Where-Object { $_.Filter -like "*$filterName*" }
if ($binding) {
    $binding | Remove-CimInstance
    Write-Host "WMI binding for '$filterName' removed."
} else {
    Write-Host "WMI binding for '$filterName' not found (already removed or never created)."
}

# Remove event filter
$filter = Get-CimInstance -Namespace root/subscription -ClassName __EventFilter -Filter "Name='$filterName'"
if ($filter) {
    $filter | Remove-CimInstance
    Write-Host "WMI event filter '$filterName' removed."
} else {
    Write-Host "WMI event filter '$filterName' not found."
}

# Remove consumer
$consumer = Get-CimInstance -Namespace root/subscription -ClassName CommandLineEventConsumer -Filter "Name='$consumerName'"
if ($consumer) {
    $consumer | Remove-CimInstance
    Write-Host "WMI consumer '$consumerName' removed."
} else {
    Write-Host "WMI consumer '$consumerName' not found."
}

# Remove the scheduled task
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Scheduled task '$taskName' removed."
} else {
    Write-Host "Scheduled task '$taskName' not found."
}

Write-Host ""
Write-Host "Uninstall complete. Game Optimizer will no longer launch automatically with Steam."
