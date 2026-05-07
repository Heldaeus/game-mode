$script:ModuleEnabled = [ordered]@{
    Explorer            = $true
    'Power Plan'        = $true
    Defender            = $true
    SysMain             = $true
    'Network Throttling' = $true
}

function Show-AudioDevice {
    $inAudio = $true
    $redraw = $true

    while ($inAudio) {
        if ($redraw) {
            [Console]::Clear()

            Write-Host ""
            Write-Host "  AUDIO DEVICE" -ForegroundColor White
            Write-Host ""
            Write-Host ""

            $devices = Get-AudioDevice -List | Where-Object { $_.Type -eq 'Playback' }
            $current = Get-AudioDevice -Playback

            $i = 1
            foreach ($device in $devices) {
                $isActive = $device.ID -eq $current.ID
                Write-Host "  " -NoNewline
                Write-Host "[$i]" -NoNewline -ForegroundColor DarkGray
                if ($isActive) {
                    Write-Host " $($device.Name)" -ForegroundColor Green
                } else {
                    Write-Host " $($device.Name)"
                }
                $i++
            }

            Write-Host ""
            Write-Host "  " -NoNewline; Write-Host "[B]" -NoNewline -ForegroundColor DarkGray; Write-Host " Back"
            Write-Host ""

            $redraw = $false
        }

        $key = [Console]::ReadKey($true)

        if ($key.KeyChar -eq 'b' -or $key.KeyChar -eq 'B') {
            $inAudio = $false
        } else {
            $idx = 0
            if ([int]::TryParse([string]$key.KeyChar, [ref]$idx)) {
                if ($idx -ge 1 -and $idx -le $devices.Count) {
                    $selected = @($devices)[$idx - 1]
                    Set-AudioDevice -ID $selected.ID | Out-Null
                    $redraw = $true
                }
            }
        }
    }
}

function Show-TamperProtection {
    Start-Process "windowsdefender://threatsettings"

    $lastState = $null

    while ($true) {
        $tamperOn = (Get-MpComputerStatus).IsTamperProtected
        $state    = if ($tamperOn) { 'Enabled' } else { 'Disabled' }

        if ($state -ne $lastState) {
            [Console]::Clear()

            Write-Host ""
            Write-Host "  TAMPER PROTECTION" -ForegroundColor White
            Write-Host ""
            Write-Host ""
            Write-Host "  Status: " -NoNewline
            if ($tamperOn) {
                Write-Host $state -ForegroundColor Red
                Write-Host ""
                Write-Host "  Turn off Tamper Protection in the" -ForegroundColor Gray
                Write-Host "  Windows Security window that opened." -ForegroundColor Gray
            } else {
                Write-Host $state -ForegroundColor Green
            }
            Write-Host ""
            Write-Host "  Note: this script will not re-enable" -ForegroundColor DarkGray
            Write-Host "  Tamper Protection automatically. Enable" -ForegroundColor DarkGray
            Write-Host "  and disable it at your own discretion." -ForegroundColor DarkGray
            Write-Host ""
            Write-Host "  Read HOW-IT-WORKS to learn why." -ForegroundColor DarkGray
            Write-Host ""
            Write-Host "  " -NoNewline; Write-Host "[B]" -NoNewline -ForegroundColor DarkGray; Write-Host " Back"
            Write-Host ""

            $lastState = $state
        }

        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.KeyChar -eq 'b' -or $key.KeyChar -eq 'B') { return }
        }

        Start-Sleep -Milliseconds 500
    }
}

function Show-ModuleConfig([string]$moduleKey, [string]$title, [string[]]$descLines) {
    while ($true) {
        [Console]::Clear()

        $enabled = $script:ModuleEnabled[$moduleKey]
        $state   = if ($enabled) { 'Enabled' } else { 'Disabled' }
        $color   = if ($enabled) { 'Green' } else { 'Red' }

        Write-Host ""
        Write-Host "  $title" -ForegroundColor White
        Write-Host ""
        Write-Host ""
        Write-Host "  Included in Game Mode: " -NoNewline
        Write-Host $state -ForegroundColor $color
        Write-Host ""
        foreach ($line in $descLines) {
            Write-Host "  $line" -ForegroundColor Gray
        }
        Write-Host ""
        Write-Host "  " -NoNewline; Write-Host "[T]" -NoNewline -ForegroundColor DarkGray; Write-Host " Toggle"
        Write-Host "  " -NoNewline; Write-Host "[B]" -NoNewline -ForegroundColor DarkGray; Write-Host " Back"
        Write-Host ""

        $key = [Console]::ReadKey($true)
        if ($key.KeyChar -eq 't' -or $key.KeyChar -eq 'T') {
            $script:ModuleEnabled[$moduleKey] = -not $script:ModuleEnabled[$moduleKey]
        } elseif ($key.KeyChar -eq 'b' -or $key.KeyChar -eq 'B') {
            return
        }
    }
}

function Show-ConfigureGameMode {
    $modules = @(
        [ordered]@{
            Key   = 'Explorer'
            Title = 'EXPLORER'
            Desc  = @(
                'Kills Explorer.exe while game mode is active,'
                'freeing CPU and GPU resources.'
            )
        }
        [ordered]@{
            Key   = 'Power Plan'
            Title = 'POWER PLAN'
            Desc  = @(
                'Switches to Ultimate Performance or High'
                'Performance power plan.'
            )
        }
        [ordered]@{
            Key   = 'Defender'
            Title = 'DEFENDER'
            Desc  = @(
                'Disables real-time protection while'
                'game mode is active.'
            )
        }
        [ordered]@{
            Key   = 'SysMain'
            Title = 'SYSMAIN'
            Desc  = @(
                'Stops the SysMain (Superfetch) service to'
                'reduce background disk and memory activity.'
            )
        }
        [ordered]@{
            Key   = 'Network Throttling'
            Title = 'NETWORK THROTTLING'
            Desc  = @(
                'Disables network throttling and sets'
                'SystemResponsiveness to 0.'
            )
        }
    )

    while ($true) {
        [Console]::Clear()

        Write-Host ""
        Write-Host "  CONFIGURE GAME MODE" -ForegroundColor White
        Write-Host ""
        Write-Host "  Choose which optimizations to include in Game Mode." -ForegroundColor Gray
        Write-Host ""

        $i = 1
        foreach ($m in $modules) {
            $enabled = $script:ModuleEnabled[$m.Key]
            $state   = if ($enabled) { 'ON ' } else { 'OFF' }
            $color   = if ($enabled) { 'Green' } else { 'Red' }
            Write-Host "  " -NoNewline
            Write-Host "[$i]" -NoNewline -ForegroundColor DarkGray
            Write-Host " $($m.Title.PadRight(22))" -NoNewline
            Write-Host $state -ForegroundColor $color
            $i++
        }

        Write-Host ""
        Write-Host "  " -NoNewline; Write-Host "[B]" -NoNewline -ForegroundColor DarkGray; Write-Host " Back"
        Write-Host ""

        $key = [Console]::ReadKey($true)

        $idx = 0
        if ([int]::TryParse([string]$key.KeyChar, [ref]$idx) -and $idx -ge 1 -and $idx -le $modules.Count) {
            $m = $modules[$idx - 1]
            Show-ModuleConfig $m.Key $m.Title $m.Desc
        } elseif ($key.KeyChar -eq 'b' -or $key.KeyChar -eq 'B') {
            return
        }
    }
}

function Show-Settings {
    $inSettings = $true
    $hasAudio   = [bool](Get-Module -ListAvailable -Name AudioDeviceCmdlets)
    $hasUltimate = Test-UltimatePerfAvailable

    while ($inSettings) {
        [Console]::Clear()

        $tamperOn = (Get-MpComputerStatus).IsTamperProtected

        Write-Host ""
        Write-Host "  SETTINGS" -ForegroundColor White
        Write-Host ""
        Write-Host ""

        if ($hasAudio) {
            Write-Host "  " -NoNewline; Write-Host "[1]" -NoNewline -ForegroundColor DarkGray; Write-Host " Audio Device"
        }

        Write-Host "  " -NoNewline; Write-Host "[C]" -NoNewline -ForegroundColor DarkGray; Write-Host " Configure Game Mode"
        Write-Host "  " -NoNewline; Write-Host "[B]" -NoNewline -ForegroundColor DarkGray; Write-Host " Back"
        Write-Host ""

        if (-not $hasAudio) {
            Write-Host "  " -NoNewline
            Write-Host "AudioDeviceCmdlets not installed." -ForegroundColor Yellow
            Write-Host "  " -NoNewline; Write-Host "[I]" -NoNewline -ForegroundColor DarkGray; Write-Host " Install to unlock Audio settings"
            Write-Host ""
        }

        if (-not $hasUltimate) {
            Write-Host "  " -NoNewline
            Write-Host "Ultimate Performance plan not available." -ForegroundColor Yellow
            Write-Host "  " -NoNewline; Write-Host "[P]" -NoNewline -ForegroundColor DarkGray; Write-Host " Provision Ultimate Performance plan"
            Write-Host ""
        }

        if ($tamperOn) {
            Write-Host "  " -NoNewline
            Write-Host "Tamper Protection is enabled - Defender cannot be toggled." -ForegroundColor Yellow
            Write-Host "  " -NoNewline; Write-Host "[T]" -NoNewline -ForegroundColor DarkGray; Write-Host " Open Defender settings to disable it"
            Write-Host ""
        }

        $key = [Console]::ReadKey($true)

        if ($hasAudio -and $key.KeyChar -eq '1') {
            Show-AudioDevice
        } elseif ($key.KeyChar -eq 'c' -or $key.KeyChar -eq 'C') {
            Show-ConfigureGameMode
        } elseif ($tamperOn -and ($key.KeyChar -eq 't' -or $key.KeyChar -eq 'T')) {
            Show-TamperProtection
        } elseif (-not $hasAudio -and ($key.KeyChar -eq 'i' -or $key.KeyChar -eq 'I')) {
            [Console]::Clear()
            Write-Host ""
            Write-Host "  Installing AudioDeviceCmdlets..." -ForegroundColor Gray
            Write-Host ""
            try {
                Install-Module AudioDeviceCmdlets -Scope CurrentUser -Force -ErrorAction Stop
                $hasAudio = $true
                [Console]::Clear()
                Write-Host ""
                Write-Host "  Installed successfully." -ForegroundColor Green
                Write-Host ""
                Start-Sleep -Seconds 1
            } catch {
                Write-Host "  Install failed: $_" -ForegroundColor Red
                Write-Host ""
                Read-Host '  Press Enter to continue'
            }
        } elseif (-not $hasUltimate -and ($key.KeyChar -eq 'p' -or $key.KeyChar -eq 'P')) {
            [Console]::Clear()
            Write-Host ""
            Write-Host "  Provisioning Ultimate Performance plan..." -ForegroundColor Gray
            Write-Host ""
            & powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $hasUltimate = $true
                [Console]::Clear()
                Write-Host ""
                Write-Host "  Provisioned successfully." -ForegroundColor Green
                Write-Host ""
                Start-Sleep -Seconds 1
            } else {
                Write-Host "  Provisioning failed. This plan requires Windows Pro/Enterprise." -ForegroundColor Red
                Write-Host ""
                Read-Host '  Press Enter to continue'
            }
        } elseif ($key.KeyChar -eq 'b' -or $key.KeyChar -eq 'B') {
            $inSettings = $false
        }
    }
}
