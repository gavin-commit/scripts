#Run it with: irm https://raw.githubusercontent.com/javier-derivco/scripts/refs/heads/main/compliancecheckv2.ps1 | iex
#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$NoGUI,
    [string]$LogPath = (Join-Path $env:TEMP "compliance-$(Get-Date -Format 'yyyy-MM-dd-HHmm').log")
)

# Define groups of processes with custom labels and associated services
$checks = @(
    @{ Name = "Defender"; Processes = @("MsSense.exe", "MsMpEng.exe"); Services = @("Sense", "WinDefend") },
    @{ Name = "Netskope"; Processes = @("stAgentSvc.exe"); Services = @("stAgentSvc") },
    @{ Name = "DLP";      Processes = @("SenseCE.exe"); Services = @("SenseCE") }
)

function Write-LogOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
}

function Test-ProcessRunning {
    param([array]$ProcessList)
    $runningProcesses = @()
    foreach ($exe in $ProcessList) {
        $processName = [System.IO.Path]::GetFileNameWithoutExtension($exe)
        $process = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if ($process) {
            $runningProcesses += $process.Name
        }
    }
    return $runningProcesses
}

function Start-ServiceGroup {
    param([array]$ServiceList, [string]$Label)
    $restartAttempted = $false
    foreach ($serviceName in $ServiceList) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service -and $service.Status -ne 'Running') {
                Write-LogOutput "Attempting to start $serviceName service for $Label" "Yellow"
                Start-Service -Name $serviceName -ErrorAction Stop
                Start-Sleep -Seconds 3
                $restartAttempted = $true
            }
        } catch {
            Write-LogOutput "Failed to start $serviceName service: $($_.Exception.Message)" "Red"
        }
    }
    return $restartAttempted
}

$anyServiceStopped = $false
$results = @()

# Initialize log file
"Compliance Check Report - $(Get-Date)" | Out-File -FilePath $LogPath -Force

foreach ($check in $checks) {
    $label = $check.Name
    $processList = $check.Processes
    $servicesList = $check.Services
    $restartAttempted = $false
    
    # Initial check
    $runningProcesses = Test-ProcessRunning -ProcessList $processList
    
    # If not running, attempt to restart services
    if ($runningProcesses.Count -eq 0) {
        Write-LogOutput "$label Not Running - attempting restart" "Yellow"
        $restartAttempted = Start-ServiceGroup -ServiceList $servicesList -Label $label
        
        if ($restartAttempted) {
            Write-LogOutput "Waiting 5 seconds for $label to start..." "Yellow"
            Start-Sleep -Seconds 5
            
            # Recheck after restart attempt
            $runningProcesses = Test-ProcessRunning -ProcessList $processList
        }
    }
    
    $status = if ($runningProcesses.Count -gt 0) { "Running" } else { "Not Running" }
    $result = [PSCustomObject]@{
        Service = $label
        Status = $status
        ProcessesFound = $runningProcesses -join ", "
        ProcessesChecked = $processList -join ", "
        RestartAttempted = $restartAttempted
    }
    
    $results += $result

    if ($runningProcesses.Count -gt 0) {
        $message = if ($restartAttempted) { "$label is now running after restart ($($runningProcesses -join ', '))" } else { "$label is running ($($runningProcesses -join ', '))" }
        Write-LogOutput $message "Green"
    } else {
        $message = if ($restartAttempted) { "$label Still Not Running after restart attempt" } else { "$label Not Running" }
        Write-LogOutput $message "Red"
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
    Write-LogOutput "`nCompliance checks pass.`nAll services are running correctly!" "Green"
    $exitCode = 0
}

# Display log file location
Write-Host "Log file saved: $LogPath" -ForegroundColor Cyan

# Keep console open - return to prompt instead of exiting
Read-Host "`nPress Enter to continue"
