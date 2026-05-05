function Show-Settings {
    $inSettings = $true

    while ($inSettings) {
        [Console]::Clear()

        $dash = ' ' + ('═' * 35)
        Write-Host ""
        Write-Host $dash -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "   SETTINGS" -ForegroundColor White
        Write-Host ""
        Write-Host $dash -ForegroundColor DarkGray
        Write-Host ""

        Write-Host "  " -NoNewline; Write-Host "[1]" -NoNewline -ForegroundColor DarkGray; Write-Host " Placeholder Option"
        Write-Host ""
        Write-Host "  " -NoNewline; Write-Host "[B]" -NoNewline -ForegroundColor DarkGray; Write-Host " Back"
        Write-Host ""

        $key = [Console]::ReadKey($true)

        if ($key.KeyChar -eq '1') {
            # placeholder — wire up real logic here
        } elseif ($key.KeyChar -eq 'b' -or $key.KeyChar -eq 'B') {
            $inSettings = $false
        }
    }
}
