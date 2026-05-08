#Requires -RunAsAdministrator
#
# _core\recovery.ps1
# Invoked by the GameModeRecovery scheduled task at logon.
# Restores system settings if the script exited without disabling game mode.

$root         = Split-Path (Split-Path $PSCommandPath -Parent) -Parent
$sentinelPath = "$root\_core\.game-mode-active"

if (-not (Test-Path $sentinelPath)) { exit 0 }

. "$root\Explorer\_module.ps1"
. "$root\Power Plan\_module.ps1"
. "$root\Defender\_module.ps1"
. "$root\SysMain\_module.ps1"
. "$root\Network Throttling\_module.ps1"
. "$root\Timer Resolution\_module.ps1"

# Explorer is typically relaunched automatically by Windows at logon,
# so only start it if it's genuinely not running.
if ((Get-ExplorerState) -ne 'Running') {
    try { Set-Explorer $false } catch {}
}
try { Set-PowerPlan 'Balanced' }   catch {}
try { Set-Defender $false }        catch {}
try { Set-SysMain $false }         catch {}
try { Set-NetworkThrottle $false } catch {}
try { Set-TimerRes $false }        catch {}

Remove-Item $sentinelPath -Force -ErrorAction SilentlyContinue
