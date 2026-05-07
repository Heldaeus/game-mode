#Requires -RunAsAdministrator
#
# game-mode-wmi-setup.ps1
# Automatically launches Game Optimizer when Steam starts.
# Reversal: run game-mode-wmi-uninstall.ps1
#
# How it works:
#   A permanent WMI event subscription fires when steam.exe is created.
#   The consumer triggers a scheduled task rather than launching the terminal
#   directly, because WMI consumers run as SYSTEM in session 0 (invisible) --
#   any GUI app launched from them won't appear on the desktop.
#   The scheduled task runs as an interactive user and opens the terminal normally.

Write-Host ""
Write-Host "Game Mode folder detected at:"
Write-Host "  $PSScriptRoot"
Write-Host ""
$userPath     = Read-Host "Press Enter to confirm, or type a different path"
$gameModeRoot = if ($userPath.Trim()) { $userPath.Trim().TrimEnd('\') } else { $PSScriptRoot }
Write-Host ""

$taskName      = "LaunchGameMode"
$filterName    = "SteamGameModeFilter"
$consumerName  = "GameModeConsumer"

# Register a scheduled task that launches Game Optimizer in the user's interactive session.
# MultipleInstances IgnoreNew prevents a second window if Steam relaunches while it's open.
$action    = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$gameModeRoot\Game Optimizer.bat`""
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet `
                -AllowStartIfOnBatteries `
                -DontStopIfGoingOnBatteries `
                -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Settings $settings -Force |
    Out-Null

Write-Host "Scheduled task '$taskName' registered."

# WMI event filter: polls root\cimv2 every 3 seconds for a new steam.exe process.
$filter = New-CimInstance -Namespace root/subscription -ClassName __EventFilter -Property @{
    Name           = $filterName
    EventNamespace = "root/cimv2"
    QueryLanguage  = "WQL"
    Query          = "SELECT * FROM __InstanceCreationEvent WITHIN 3 " +
                     "WHERE TargetInstance ISA 'Win32_Process' " +
                     "AND TargetInstance.Name = 'steam.exe'"
}

Write-Host "WMI event filter '$filterName' registered."

# WMI consumer: triggers the scheduled task when the filter fires.
$consumer = New-CimInstance -Namespace root/subscription -ClassName CommandLineEventConsumer -Property @{
    Name                = $consumerName
    CommandLineTemplate = "schtasks.exe /run /tn `"$taskName`""
}

Write-Host "WMI consumer '$consumerName' registered."

New-CimInstance -Namespace root/subscription -ClassName __FilterToConsumerBinding -Property @{
    Filter   = $filter
    Consumer = $consumer
} | Out-Null

Write-Host "Binding created."
Write-Host ""
Write-Host "Done. Game Optimizer will launch automatically when Steam starts."
