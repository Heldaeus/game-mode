$script:ModuleEnabled = [ordered]@{
    Explorer            = $true
    'Power Plan'        = $true
    Defender            = $true
    SysMain             = $true
    'Network Throttling' = $true
    'Timer Resolution'   = $true
}

$script:ConfigPath = "$root\_core\.module-config.json"

if (Test-Path $script:ConfigPath) {
    try {
        $saved = Get-Content $script:ConfigPath -Raw | ConvertFrom-Json
        foreach ($key in @($script:ModuleEnabled.Keys)) {
            $prop = $saved.PSObject.Properties[$key]
            if ($null -ne $prop) { $script:ModuleEnabled[$key] = [bool]$prop.Value }
        }
    } catch {}
}

function Save-ModuleConfig {
    $script:ModuleEnabled | ConvertTo-Json | Set-Content $script:ConfigPath -Force
}

function Get-TamperProtected {
    try { return (Get-MpComputerStatus -ErrorAction Stop).IsTamperProtected } catch { return $false }
}

# Tamper Protection blocks Defender changes — disable the module automatically at startup.
# This does not modify the saved config, so the preference is restored if TP is later turned off.
if (Get-TamperProtected) {
    $script:ModuleEnabled['Defender'] = $false
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
        $tamperOn = Get-TamperProtected
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

        $tamperLocked = $moduleKey -eq 'Defender' -and (Get-TamperProtected)

        Write-Host ""
        Write-Host "  $title" -ForegroundColor White
        Write-Host ""
        Write-Host ""

        if ($tamperLocked) {
            Write-Host "  Included in Game Mode: " -NoNewline
            Write-Host "Locked" -ForegroundColor Red
            Write-Host ""
            Write-Host "  " -NoNewline
            Write-Host "Tamper Protection is enabled - Defender cannot be toggled." -ForegroundColor Yellow
            Write-Host "  " -NoNewline; Write-Host "[T]" -NoNewline -ForegroundColor DarkGray; Write-Host " Open Defender settings to disable it"
            Write-Host ""
            Write-Host "  " -NoNewline; Write-Host "[B]" -NoNewline -ForegroundColor DarkGray; Write-Host " Back"
            Write-Host ""

            $key = [Console]::ReadKey($true)
            if ($key.KeyChar -eq 't' -or $key.KeyChar -eq 'T') {
                Show-TamperProtection
                if (-not (Get-TamperProtected)) {
                    $pref = $true
                    try {
                        $s = Get-Content $script:ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json
                        $p = $s.PSObject.Properties['Defender']
                        if ($null -ne $p) { $pref = [bool]$p.Value }
                    } catch {}
                    $script:ModuleEnabled['Defender'] = $pref
                }
            } elseif ($key.KeyChar -eq 'b' -or $key.KeyChar -eq 'B') { return }
        } else {
            $enabled = $script:ModuleEnabled[$moduleKey]
            $state   = if ($enabled) { 'Enabled' } else { 'Disabled' }
            $color   = if ($enabled) { 'Green' } else { 'Red' }

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
                Save-ModuleConfig
            } elseif ($key.KeyChar -eq 'b' -or $key.KeyChar -eq 'B') {
                return
            }
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
        [ordered]@{
            Key   = 'Timer Resolution'
            Title = 'TIMER RESOLUTION'
            Desc  = @(
                'Sets Windows timer resolution to 0.5ms for'
                'lower frame time variance.'
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

function Get-GpuMsiInfo {
    $gpus = Get-PnpDevice -Class Display -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'OK' }
    foreach ($gpu in $gpus) {
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($gpu.InstanceId)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
        $msi = $null
        if (Test-Path $regPath) {
            $msi = (Get-ItemProperty $regPath -Name MSISupported -ErrorAction SilentlyContinue).MSISupported
        }
        [PSCustomObject]@{ Name = $gpu.FriendlyName; RegPath = $regPath; MSI = $msi }
    }
}

function Show-GpuMsi {
    while ($true) {
        [Console]::Clear()

        Write-Host ""
        Write-Host "  GPU MSI MODE" -ForegroundColor White
        Write-Host ""
        Write-Host "  Message Signaled Interrupts reduce GPU interrupt latency." -ForegroundColor Gray
        Write-Host "  Changes require a reboot to take effect."                  -ForegroundColor Gray
        Write-Host ""

        $gpus = @(Get-GpuMsiInfo)

        if (-not $gpus) {
            Write-Host "  No display devices found." -ForegroundColor Red
            Write-Host ""
            Write-Host "  " -NoNewline; Write-Host "[B]" -NoNewline -ForegroundColor DarkGray; Write-Host " Back"
            Write-Host ""
            $key = [Console]::ReadKey($true)
            if ($key.KeyChar -eq 'b' -or $key.KeyChar -eq 'B') { return }
            continue
        }

        foreach ($gpu in $gpus) {
            $stateLabel = switch ($gpu.MSI) { 1 { 'Enabled' } 0 { 'Disabled' } default { 'Unknown' } }
            $stateColor = if ($gpu.MSI -eq 1) { 'Green' } elseif ($gpu.MSI -eq 0) { 'Red' } else { 'Yellow' }
            Write-Host "  $($gpu.Name)"
            Write-Host "  MSI: " -NoNewline
            Write-Host $stateLabel -ForegroundColor $stateColor
            Write-Host ""
        }

        $toEnable = @($gpus | Where-Object { $_.MSI -ne 1 })

        if ($toEnable) {
            Write-Host "  " -NoNewline; Write-Host "[E]" -NoNewline -ForegroundColor DarkGray; Write-Host " Enable MSI on all GPUs"
        }
        Write-Host "  " -NoNewline; Write-Host "[B]" -NoNewline -ForegroundColor DarkGray; Write-Host " Back"
        Write-Host ""

        $key = [Console]::ReadKey($true)

        if ($toEnable -and ($key.KeyChar -eq 'e' -or $key.KeyChar -eq 'E')) {
            foreach ($gpu in $gpus) {
                if (-not (Test-Path $gpu.RegPath)) { New-Item -Path $gpu.RegPath -Force | Out-Null }
                Set-ItemProperty $gpu.RegPath -Name MSISupported -Value 1 -Type DWord
            }
            [Console]::Clear()
            Write-Host ""
            Write-Host "  Done. Reboot to apply." -ForegroundColor Green
            Write-Host ""
            Start-Sleep -Seconds 2
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

        $tamperOn = Get-TamperProtected

        Write-Host ""
        Write-Host "  SETTINGS" -ForegroundColor White
        Write-Host ""
        Write-Host ""

        if ($hasAudio) {
            Write-Host "  " -NoNewline; Write-Host "[1]" -NoNewline -ForegroundColor DarkGray; Write-Host " Audio Device"
        }

        Write-Host "  " -NoNewline; Write-Host "[C]" -NoNewline -ForegroundColor DarkGray; Write-Host " Configure Game Mode"
        Write-Host "  " -NoNewline; Write-Host "[G]" -NoNewline -ForegroundColor DarkGray; Write-Host " GPU MSI Mode"
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
        } elseif ($key.KeyChar -eq 'g' -or $key.KeyChar -eq 'G') {
            Show-GpuMsi
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
