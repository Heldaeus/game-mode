$script:UltimatePerfGuid = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
$script:BalancedGuid     = '381b4222-f694-41f0-9685-ff5bb260df2e'

function Get-PowerPlanState {
    $active = & powercfg /getactivescheme
    if ($active -match $script:UltimatePerfGuid) { 'Ultimate Performance' }
    elseif ($active -match $script:BalancedGuid)  { 'Balanced' }
    else { 'Other' }
}

function Set-PowerPlan([string]$plan) {
    if ($plan -eq 'Ultimate') {
        & powercfg /setactive $script:UltimatePerfGuid
    } else {
        & powercfg /setactive $script:BalancedGuid
    }
}
