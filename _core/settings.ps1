function Show-AudioDevice {
    $inAudio = $true
    $redraw = $true

    while ($inAudio) {
        if ($redraw) {
            [Console]::Clear()

            $dash = ' ' + ([string][char]0x2550 * 35)
            Write-Host ""
            Write-Host $dash -ForegroundColor DarkGray
            Write-Host ""
            Write-Host "   AUDIO DEVICE" -ForegroundColor White
            Write-Host ""
            Write-Host $dash -ForegroundColor DarkGray
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

function Show-Settings {
    $inSettings = $true
    $hasAudio = [bool](Get-Module -ListAvailable -Name AudioDeviceCmdlets)

    while ($inSettings) {
        [Console]::Clear()

        $dash = ' ' + ([string][char]0x2550 * 35)
        Write-Host ""
        Write-Host $dash -ForegroundColor DarkGray
        Write-Host ""
        $title = 'SETTINGS'
        $pad = [string]::new(' ', [Math]::Floor(($dash.Length - $title.Length) / 2))
        Write-Host ($pad + $title) -ForegroundColor White
        Write-Host ""
        Write-Host $dash -ForegroundColor DarkGray
        Write-Host ""

        if ($hasAudio) {
            Write-Host "  " -NoNewline; Write-Host "[1]" -NoNewline -ForegroundColor DarkGray; Write-Host " Audio Device"
        }

        Write-Host "  " -NoNewline; Write-Host "[B]" -NoNewline -ForegroundColor DarkGray; Write-Host " Back"
        Write-Host ""

        if (-not $hasAudio) {
            Write-Host "  " -NoNewline
            Write-Host "AudioDeviceCmdlets not installed." -ForegroundColor Yellow
            Write-Host "  " -NoNewline; Write-Host "[I]" -NoNewline -ForegroundColor DarkGray; Write-Host " Install to unlock Audio settings"
            Write-Host ""
        }

        $key = [Console]::ReadKey($true)

        if ($hasAudio -and $key.KeyChar -eq '1') {
            Show-AudioDevice
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
        } elseif ($key.KeyChar -eq 'b' -or $key.KeyChar -eq 'B') {
            $inSettings = $false
        }
    }
}
