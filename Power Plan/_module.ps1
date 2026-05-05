$script:UltimatePerfGuid = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
$script:HighPerfGuid     = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
$script:BalancedGuid     = '381b4222-f694-41f0-9685-ff5bb260df2e'

function Get-PowerPlanState {
    $active = & powercfg /getactivescheme
    if ($active -match $script:UltimatePerfGuid -or $active -match $script:HighPerfGuid) { 'Ultimate Performance' }
    elseif ($active -match $script:BalancedGuid) { 'Balanced' }
    else { 'Other' }
}

function Test-UltimatePerfAvailable {
    $list = & powercfg /list 2>&1
    return [bool]($list | Where-Object { $_ -match 'Ultimate Performance' })
}

function Set-PowerPlan([string]$plan) {
    if ($plan -eq 'Ultimate') {
        & powercfg /setactive $script:UltimatePerfGuid
        # Ultimate Performance is hidden on laptops — fall back to High Performance
        if ($LASTEXITCODE -ne 0) {
            & powercfg /setactive $script:HighPerfGuid
        }
    } else {
        & powercfg /setactive $script:BalancedGuid
    }
}
