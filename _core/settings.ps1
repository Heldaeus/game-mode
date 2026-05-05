function Show-AudioDevice {
    $inAudio = $true
    $redraw = $true

    while ($inAudio) {
        if ($redraw) {
            [Console]::Clear()

            $dash = ' ' + ('-' * 35)
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

        $dash = ' ' + ('-' * 35)
        Write-Host ""
        Write-Host $dash -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "   SETTINGS" -ForegroundColor White
        Write-Host ""
        Write-Host $dash -ForegroundColor DarkGray
        Write-Host ""

        if ($hasAudio) {
            Write-Host "  " -NoNewline; Write-Host "[1]" -NoNewline -ForegroundColor DarkGray; Write-Host " Audio Device"
        }

        Write-Host "  " -NoNewline; Write-Host "[B]" -NoNewline -ForegroundColor DarkGray; Write-Host " Back"
        Write-Host ""

        if (-not $hasAudio) {
            Write-Host $dash -ForegroundColor DarkGray
            Write-Host ""
            Write-Host "  " -NoNewline
            Write-Host "AudioDeviceCmdlets not installed." -ForegroundColor Yellow
            Write-Host "  " -NoNewline; Write-Host "[I]" -NoNewline -ForegroundColor DarkGray; Write-Host " Install to unlock Audio settings"
            Write-Host ""
        }

        $key = [Console]::ReadKey($true)

        if ($hasAudio -and $key.KeyChar -eq '1') {
            Show-AudioDevice
        } elseif (-not $hasAudio -and ($key.KeyChar -eq 'i' -or $key.KeyChar -eq 'I')) {
            # launch install script here
        } elseif ($key.KeyChar -eq 'b' -or $key.KeyChar -eq 'B') {
            $inSettings = $false
        }
    }
}
