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
            # audio settings — wire up real logic here
        } elseif (-not $hasAudio -and ($key.KeyChar -eq 'i' -or $key.KeyChar -eq 'I')) {
            # launch install script here
        } elseif ($key.KeyChar -eq 'b' -or $key.KeyChar -eq 'B') {
            $inSettings = $false
        }
    }
}
