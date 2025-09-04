<#
.SYNOPSIS
    Find Tor Browser installations via MS Graph
.DESCRIPTION
    Searches Intune discovered apps for Tor Browser and reports device name and primary user
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
    Write-Host "Searching for Tor Browser installations..." -ForegroundColor Green
    
    # Get all detected apps matching Tor (various naming conventions)
    Write-Host "Searching for 'Tor Browser'..." -ForegroundColor Cyan
    $torBrowserApps = Get-MgDeviceManagementDetectedApp -Filter "contains(displayName,'Tor Browser')" -All
    
    Write-Host "Searching for 'Tor'..." -ForegroundColor Cyan
    $torApps = Get-MgDeviceManagementDetectedApp -Filter "contains(displayName,'Tor')" -All
    
    # Combine and deduplicate
    $allTorApps = @()
    $allTorApps += $torBrowserApps
    $allTorApps += $torApps
    $torApps = $allTorApps | Sort-Object Id -Unique
    
    if ($torApps.Count -eq 0) {
        Write-Host "No Tor Browser installations found." -ForegroundColor Yellow
        exit
    }
    
    Write-Host "Found $($torApps.Count) Tor Browser app installation(s)" -ForegroundColor Green
    
    $results = @()
    
    foreach ($app in $torApps) {
        Write-Host "Processing app: $($app.DisplayName)" -ForegroundColor Cyan
        
        # Get managed devices where this app is installed
        $managedDevices = Get-MgDeviceManagementDetectedAppManagedDevice -DetectedAppId $app.Id -All
        
        foreach ($deviceRef in $managedDevices) {
            # Get full device details
            $device = Get-MgDeviceManagementManagedDevice -ManagedDeviceId $deviceRef.Id
            
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
            }
            
            $results += $result
        }
    }
    
    # Display results
    if ($results.Count -gt 0) {
        Write-Host "`nTor Browser Installations Found:" -ForegroundColor Green
        Write-Host "=" * 60 -ForegroundColor Green
        
        $results | Format-Table -AutoSize
        
        # Export to CSV
        $csvPath = "TorBrowser-Installations-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
        $results | Export-Csv -Path $csvPath -NoTypeInformation
        Write-Host "`nResults exported to: $csvPath" -ForegroundColor Yellow
        
    } else {
        Write-Host "No devices found with Tor Browser installed." -ForegroundColor Yellow
    }
    
} catch {
    Write-Error "Error occurred: $($_.Exception.Message)"
} finally {
    # Disconnect from Graph
    Disconnect-MgGraph
    Write-Host "`nDisconnected from Microsoft Graph" -ForegroundColor Gray
}