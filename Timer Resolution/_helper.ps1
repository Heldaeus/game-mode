Add-Type @"
using System;
using System.Runtime.InteropServices;
public class NtTimerHelper {
    [DllImport("ntdll.dll")]
    public static extern int NtSetTimerResolution(uint DesiredResolution, bool SetResolution, out uint CurrentResolution);
}
"@

$cur = [uint32]0
[NtTimerHelper]::NtSetTimerResolution(5000, $true, [ref]$cur) | Out-Null

while ($true) { Start-Sleep -Seconds 30 }
