<#
.SYNOPSIS
    Find NordVPN installations via MS Graph
.DESCRIPTION
    Searches Intune discovered apps for NordVPN and reports device name and primary user
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
    Write-Host "Searching for NordVPN installations..." -ForegroundColor Green
    
    # Get all detected apps matching NordVPN
    $nordvpnApps = Get-MgDeviceManagementDetectedApp -Filter "contains(displayName,'NordVPN')" -All
    
    if ($nordvpnApps.Count -eq 0) {
        Write-Host "No NordVPN installations found." -ForegroundColor Yellow
        exit
    }
    
    Write-Host "Found $($nordvpnApps.Count) NordVPN app installation(s)" -ForegroundColor Green
    
    $results = @()
    
    foreach ($app in $nordvpnApps) {
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
        Write-Host "`nNordVPN Installations Found:" -ForegroundColor Green
        Write-Host "=" * 60 -ForegroundColor Green
        
        $results | Format-Table -AutoSize
        
        # Export to CSV
        $csvPath = "NordVPN-Installations-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
        $results | Export-Csv -Path $csvPath -NoTypeInformation
        Write-Host "`nResults exported to: $csvPath" -ForegroundColor Yellow
        
    } else {
        Write-Host "No devices found with NordVPN installed." -ForegroundColor Yellow
    }
    
} catch {
    Write-Error "Error occurred: $($_.Exception.Message)"
} finally {
    # Disconnect from Graph
    Disconnect-MgGraph
    Write-Host "`nDisconnected from Microsoft Graph" -ForegroundColor Gray
}