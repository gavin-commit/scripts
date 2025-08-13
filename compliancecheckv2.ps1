#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$NoGUI,
    [string]$LogPath = (Join-Path $env:TEMP "compliance-$(Get-Date -Format 'yyyy-MM-dd-HHmm').log")
)

# Define groups of processes with custom labels
$checks = @(
    @{ Name = "Defender"; Processes = @("MsSense.exe", "MsMpEng.exe") },
    @{ Name = "Netskope"; Processes = @("stAgentSvc.exe") },
    @{ Name = "DLP";      Processes = @("SenseCE.exe") }
)

function Write-LogOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
}

$anyServiceStopped = $false
$results = @()

# Initialize log file
"Compliance Check Report - $(Get-Date)" | Out-File -FilePath $LogPath -Force

foreach ($check in $checks) {
    $label = $check.Name
    $processList = $check.Processes
    $runningProcesses = @()

    foreach ($exe in $processList) {
        $processName = [System.IO.Path]::GetFileNameWithoutExtension($exe)
        
        $process = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if ($process) {
            $runningProcesses += $process.Name
        }
    }

    $result = [PSCustomObject]@{
        Service = $label
        Status = if ($runningProcesses.Count -gt 0) { "Running" } else { "Not Running" }
        ProcessesFound = $runningProcesses -join ", "
        ProcessesChecked = $processList -join ", "
    }
    
    $results += $result

    if ($runningProcesses.Count -gt 0) {
        Write-LogOutput "$label is running ($($runningProcesses -join ', '))" "Green"
    } else {
        Write-LogOutput "$label Not Running" "Red"
        $anyServiceStopped = $true
    }
}

# Output results as table
Write-Host "`nSummary:" -ForegroundColor Cyan
$results | Format-Table -AutoSize | Out-String | Write-Host

# Final summary
if ($anyServiceStopped) {
    Write-LogOutput "`nACTION REQUIRED: Some services are not running" "Red"
    $exitCode = 1
} else {
    Write-LogOutput "`nAll services are running correctly" "Green"
    $exitCode = 0
}

# Open log file unless NoGUI switch is used
if (-not $NoGUI -and (Test-Path $LogPath)) {
    try {
        Start-Process notepad.exe $LogPath
    } catch {
        Write-Warning "Could not open log file in Notepad: $_"
        Write-Host "Log file location: $LogPath"
    }
}

# Keep console open
Write-Host "`nPress any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
exit $exitCode