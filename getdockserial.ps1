<#
.SYNOPSIS
    Docking Station Inventory Script for Intune Deployment
.DESCRIPTION
    Collects docking station information and reports to central location
.NOTES
    Intune Deployment Settings:
    - Run this script using the logged-on credentials: No
    - Enforce script signature check: No
    - Run script in 64-bit PowerShell: Yes
#>

# Script configuration
$centralPath = "\\mgsops.net\data\dil\departmentdata\inventory\docking_report.csv"
$logPath = "$env:ProgramData\DockingReport\log.txt"
$maxRetries = 3
$retryDelay = 30

# Create log directory if it doesn't exist
$logDir = Split-Path $logPath -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp [$Level] $Message"
    Add-Content -Path $logPath -Value $logMessage
    Write-Output $logMessage
}

try {
    Write-Log "Starting docking station inventory script"
    
    # Check if machine is on the required subnet (10.76.212.0/24)
    Write-Log "Checking network subnet eligibility"
    $ethernetAdapters = Get-NetAdapter | Where-Object {$_.MediaType -eq "802.3" -and $_.Status -eq "Up"}
    $validSubnet = $false
    
    foreach ($adapter in $ethernetAdapters) {
        $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        foreach ($ip in $ipConfig) {
            if ($ip.IPAddress -match "^10\.76\.212\.") {
                $validSubnet = $true
                Write-Log "Found valid subnet IP: $($ip.IPAddress) on adapter: $($adapter.Name)"
                break
            }
        }
        if ($validSubnet) { break }
    }
    
    if (-not $validSubnet) {
        Write-Log "Machine not on required subnet (10.76.212.0/24). Script will not continue." "WARN"
        exit 0
    }
    
    # Get connected docking station information
    Write-Log "Querying for docking stations"
    $dockingStations = Get-WmiObject -Class Win32_PnPEntity | 
        Select-Object Name, PNPDeviceID | 
        Where-Object {$_.Name -like "*docking*" -or $_.Name -like "*dock*" -or $_.Name -like "*hub*"}
    
    # Get Dell WD docking station serial numbers with enhanced error handling
    Write-Log "Querying Dell inventory for WD docking stations"
    $dellDockingStations = $null
    $dellQuerySuccess = $false
    
    # Method 1: Try Get-WmiObject with full error handling
    try {
        Write-Log "Attempting Dell WMI query method 1 (Get-WmiObject)"
        $dellDockingStations = Get-WmiObject -Namespace "root\dell\sysinv" -Class "dell_softwareidentity" -ErrorAction Stop | 
            Select-Object serialnumber, elementname | 
            Where-Object {$_.elementname -like "WD*"}
        
        if ($dellDockingStations) {
            $dellQuerySuccess = $true
            Write-Log "Dell WMI query method 1 successful. Found $(@($dellDockingStations).Count) WD devices"
            foreach ($device in $dellDockingStations) {
                Write-Log "Dell device found: $($device.elementname) - Serial: $($device.serialnumber)"
            }
        } else {
            Write-Log "Dell WMI query method 1 successful but no WD devices found"
        }
    } catch {
        Write-Log "Dell WMI query method 1 failed: $($_.Exception.Message)" "WARN"
    }
    
    # Method 2: Try gwmi if method 1 failed
    if (-not $dellQuerySuccess) {
        try {
            Write-Log "Attempting Dell WMI query method 2 (gwmi)"
            $dellDockingStations = gwmi -Namespace "root\dell\sysinv" -Class "dell_softwareidentity" -ErrorAction Stop | 
                Select-Object serialnumber, elementname | 
                Where-Object {$_.elementname -like "WD*"}
            
            if ($dellDockingStations) {
                $dellQuerySuccess = $true
                Write-Log "Dell WMI query method 2 successful. Found $(@($dellDockingStations).Count) WD devices"
                foreach ($device in $dellDockingStations) {
                    Write-Log "Dell device found (method 2): $($device.elementname) - Serial: $($device.serialnumber)"
                }
            } else {
                Write-Log "Dell WMI query method 2 successful but no WD devices found"
            }
        } catch {
            Write-Log "Dell WMI query method 2 also failed: $($_.Exception.Message)" "ERROR"
        }
    }
    
    if (-not $dellQuerySuccess) {
        Write-Log "All Dell WMI query methods failed. Dell WMI namespace not available or accessible" "WARN"
    }
    
    # Process docking station information
    if ($dockingStations) {
        $dockingStation = $dockingStations | Select-Object -First 1
        $dockingStationName = $dockingStation.Name
        $dockingStationSerial = if ($dockingStation.PNPDeviceID.Contains('\\')) {
            $dockingStation.PNPDeviceID.Split('\\')[1]
        } else {
            $dockingStation.PNPDeviceID
        }
        
        # Enhanced serial number detection for Dell WD docking stations
        if ($dellQuerySuccess -and $dellDockingStations) {
            $dellDock = $dellDockingStations | Select-Object -First 1
            if ($dellDock.serialnumber -and $dellDock.serialnumber -ne "") {
                $dockingStationSerial = $dellDock.serialnumber
                $dockingStationModel = $dellDock.elementname
                Write-Log "Using Dell inventory data - Model: $dockingStationModel, Serial: $dockingStationSerial"
            } else {
                $dockingStationModel = $dockingStationName
                Write-Log "Dell inventory found but no serial number available, using PnP data"
            }
        } else {
            $dockingStationModel = $dockingStationName
            Write-Log "Using PnP device data - Name: $dockingStationName"
        }
    } else {
        $dockingStationName = "None"
        $dockingStationSerial = "None"
        $dockingStationModel = "None"
        Write-Log "No docking station detected"
    }

    # Get system information
    $computerInfo = Get-ComputerInfo
    $computerName = $env:COMPUTERNAME
    $userName = try { 
        (Get-WmiObject -Class Win32_ComputerSystem).UserName 
    } catch { 
        "Unknown" 
    }
    $serialNumber = $computerInfo.CsSystemSKUNumber
    $model = $computerInfo.CsModel
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # Create report object
    $reportData = [PSCustomObject]@{
        ComputerName = $computerName
        ComputerSerial = $serialNumber
        ComputerModel = $model
        UserName = $userName
        DockingStationName = $dockingStationName
        DockingStationModel = $dockingStationModel
        DockingStationSerial = $dockingStationSerial
        LastChecked = $timestamp
        ScriptVersion = "1.1"
    }

    Write-Log "Report data prepared for computer: $computerName"

    # Attempt to write to central location with retry logic
    $attempt = 1
    $success = $false
    
    while ($attempt -le $maxRetries -and -not $success) {
        try {
            Write-Log "Attempting to write to central location (attempt $attempt of $maxRetries)"
            
            # Test network connectivity
            if (-not (Test-Path (Split-Path $centralPath -Parent))) {
                throw "Cannot access network path: $(Split-Path $centralPath -Parent)"
            }
            
            # Write to CSV
            if (-not (Test-Path $centralPath)) {
                Write-Log "Creating new CSV file with headers"
                $reportData | Export-Csv -Path $centralPath -NoTypeInformation -Encoding UTF8
            } else {
                Write-Log "Appending to existing CSV file"
                $reportData | Export-Csv -Path $centralPath -NoTypeInformation -Append -Encoding UTF8
            }
            
            $success = $true
            Write-Log "Successfully wrote report to $centralPath"
            
        } catch {
            Write-Log "Attempt $attempt failed: $($_.Exception.Message)" "ERROR"
            
            if ($attempt -lt $maxRetries) {
                Write-Log "Waiting $retryDelay seconds before retry"
                Start-Sleep -Seconds $retryDelay
            }
            $attempt++
        }
    }

    # Fallback: Save locally if central write failed
    if (-not $success) {
        $localPath = "$env:ProgramData\DockingReport\docking_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        Write-Log "Writing to local fallback location: $localPath" "WARN"
        $reportData | Export-Csv -Path $localPath -NoTypeInformation -Encoding UTF8
    }

    Write-Log "Script completed successfully"
    exit 0

} catch {
    Write-Log "Script failed with error: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    exit 1
}