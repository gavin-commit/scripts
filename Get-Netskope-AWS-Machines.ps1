<#
.SYNOPSIS
    Find Netskope installations on AWS machines via MS Graph
.DESCRIPTION
    Searches Intune discovered apps for Netskope and reports device name and primary user
    Only includes machines with names starting with "AWS"
#>

# Install required module if not present
if (!(Get-Module -ListAvailable -Name Microsoft.Graph)) {
    Write-Host "Installing Microsoft.Graph module..." -ForegroundColor Yellow
    Install-Module Microsoft.Graph -Force -AllowClobber
}

# Import required modules
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.DeviceManagement

# Connect to Graph with required permissions
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
Connect-MgGraph -Scopes @(
    "DeviceManagementManagedDevices.Read.All",
    "DeviceManagementApps.Read.All"
)

try {
    Write-Host "Searching for Netskope installations on AWS machines..." -ForegroundColor Green
    
    # Get all detected apps matching Netskope
    $netskopeApps = Get-MgDeviceManagementDetectedApp -Filter "contains(displayName,'Netskope')" -All
    
    if ($netskopeApps.Count -eq 0) {
        Write-Host "No Netskope installations found." -ForegroundColor Yellow
        exit
    }
    
    Write-Host "Found $($netskopeApps.Count) Netskope app installation(s)" -ForegroundColor Green
    
    $results = @()
    
    foreach ($app in $netskopeApps) {
        Write-Host "Processing app: $($app.DisplayName)" -ForegroundColor Cyan
        
        # Get managed devices where this app is installed
        $managedDevices = Get-MgDeviceManagementDetectedAppManagedDevice -DetectedAppId $app.Id -All
        
        foreach ($deviceRef in $managedDevices) {
            # Get full device details
            $device = Get-MgDeviceManagementManagedDevice -ManagedDeviceId $deviceRef.Id
            
            # Filter for AWS machines only
            if ($device.DeviceName -like "AWS*") {
                Write-Host "Found AWS machine: $($device.DeviceName)" -ForegroundColor Green
                
                # Get primary user if available
                $primaryUser = ""
                if ($device.UserId) {
                    try {
                        $user = Get-MgUser -UserId $device.UserId -Property "DisplayName,UserPrincipalName" -ErrorAction SilentlyContinue
                        $primaryUser = "$($user.DisplayName) ($($user.UserPrincipalName))"
                    } catch {
                        $primaryUser = $device.UserId
                    }
                }
                
                $result = [PSCustomObject]@{
                    'App Name' = $app.DisplayName
                    'App Version' = $app.Version
                    'Device Name' = $device.DeviceName
                    'Primary User' = $primaryUser
                    'OS' = $device.OperatingSystem
                    'Last Sync' = $device.LastSyncDateTime
                    'Compliance' = $device.ComplianceState
                    'Enrollment Date' = $device.EnrolledDateTime
                }
                
                $results += $result
            }
        }
    }
    
    # Display results
    if ($results.Count -gt 0) {
        Write-Host "`nNetskope Installations Found on AWS Machines:" -ForegroundColor Green
        Write-Host "=" * 60 -ForegroundColor Green
        
        $results | Format-Table -AutoSize
        
        # Export to CSV
        $csvPath = "Netskope-AWS-Machines-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
        $results | Export-Csv -Path $csvPath -NoTypeInformation
        Write-Host "`nResults exported to: $csvPath" -ForegroundColor Yellow
        
        Write-Host "`nSummary: Found Netskope on $($results.Count) AWS machine(s)" -ForegroundColor Green
        
    } else {
        Write-Host "No AWS machines found with Netskope installed." -ForegroundColor Yellow
    }
    
} catch {
    Write-Error "Error occurred: $($_.Exception.Message)"
} finally {
    # Disconnect from Graph
    Disconnect-MgGraph
    Write-Host "`nDisconnected from Microsoft Graph" -ForegroundColor Gray
}