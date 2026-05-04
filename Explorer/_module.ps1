function Get-ExplorerState {
    # Get-Process returns nothing (not an error) if the process isn't running,
    # so -ErrorAction SilentlyContinue is enough — no try/catch needed.
    if (Get-Process explorer -ErrorAction SilentlyContinue) { 'Running' } else { 'Stopped' }
}

function Set-Explorer([bool]$stop) {
    if ($stop) {
        # taskkill /f /im kills all instances simultaneously. Stop-Process only terminates
        # one at a time, giving Windows enough time to auto-relaunch the shell before
        # the last instance dies — taskkill wins that race and keeps it dead.
        if (Get-Process explorer -ErrorAction SilentlyContinue) {
            & taskkill /f /im explorer.exe | Out-Null
            # Poll until the process is fully gone so the menu state is accurate on redraw.
            while (Get-Process explorer -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 100 }
        }
    } else {
        # Starting explorer with no arguments re-launches the full shell (taskbar + desktop).
        Start-Process explorer
    }
}
