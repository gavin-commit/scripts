# Define groups of processes with custom labels
$checks = @(
    @{ Name = "Defender"; Processes = @("MsSense.exe", "MsMpEng.exe", "msmpeng.exe") },
    @{ Name = "Netskope"; Processes = @("stAgentSvc.exe") },
    @{ Name = "DLP";      Processes = @("SenseCE.exe", "sensece.exe") }
)

$anyServiceStopped = $false
$log = ""

foreach ($check in $checks) {
    $label = $check.Name
    $processList = $check.Processes
    $isRunning = $false

    foreach ($exe in $processList) {
        $processName = [System.IO.Path]::GetFileNameWithoutExtension($exe)

        try {
            $process = Get-Process -Name $processName -ErrorAction Stop
            $isRunning = $true
            break
        } catch {
            # Ignore errors
        }
    }

    if ($isRunning) {
        Write-Host "$label is running." -ForegroundColor Green
        $log += "$label is running.`r`n"
    } else {
        Write-Host "$label Not Running" -ForegroundColor Red
        $log += "$label Not Running`r`n"
        $anyServiceStopped = $true
    }
}

# Final summary
if ($anyServiceStopped) {
    Write-Host "`nPlease check the above stopped services." -ForegroundColor Red
    $log += "`r`nPlease check the above stopped services.`r`n"
} else {
    Write-Host "`nAll is OK." -ForegroundColor Green
    $log += "`r`nAll is OK.`r`n"
}

# Write the summary to a temp file and open it in Notepad
$tempFile = [System.IO.Path]::GetTempFileName() + ".txt"
[System.IO.File]::WriteAllText($tempFile, $log)
Start-Process notepad.exe $tempFile
