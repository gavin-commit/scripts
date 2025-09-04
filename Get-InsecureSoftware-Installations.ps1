<#
.SYNOPSIS
    Find potentially insecure software via MS Graph
.DESCRIPTION
    Searches Intune discovered apps for software that may pose security risks and reports device name and primary user
#>

# Install required module if not present
if (!(Get-Module -ListAvailable -Name Microsoft.Graph)) {
    Write-Host "Installing Microsoft.Graph module..." -ForegroundColor Yellow
    Install-Module Microsoft.Graph -Force -AllowClobber
}

# Import required modules
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.DeviceManagement

# Display scan started banner
Write-Host @"

  ██████   ██████  █████  ███    ██     ███████ ████████  █████  ██████  ████████ ███████ ██████  
 ██        ██      ██   ██ ████   ██     ██         ██    ██   ██ ██   ██    ██    ██      ██   ██ 
 ██████   ██      ███████ ██ ██  ██     ███████    ██    ███████ ██████     ██    █████   ██   ██ 
      ██  ██      ██   ██ ██  ██ ██          ██    ██    ██   ██ ██   ██    ██    ██      ██   ██ 
 ██████    ██████ ██   ██ ██   ████     ███████    ██    ██   ██ ██   ██    ██    ███████ ██████  
                                                                                                    
"@ -ForegroundColor Red

# Connect to Graph with required permissions
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
Connect-MgGraph -Scopes @(
    "DeviceManagementManagedDevices.Read.All",
    "DeviceManagementApps.Read.All"
)

# Define potentially insecure/problematic software categories
$InsecureSoftwarePatterns = @(
    # VPN Software (unauthorized)
    "VPN", "NordVPN", "ExpressVPN", "Private Internet Access", "CyberGhost", "Surfshark", "ProtonVPN",
    
    # Anonymous browsing/Privacy tools
    "Tails", "Whonix",
    
    # P2P/File sharing
    "BitTorrent", "uTorrent", "qBittorrent", "Transmission", "Vuze", "Deluge", "LimeWire", "Kazaa",
    
    # Remote access tools (unauthorized)
    "TeamViewer", "AnyDesk", "Chrome Remote Desktop", "LogMeIn", "GoToMyPC", "VNC", "RDP", "Splashtop",
    
    # Password crackers/Security tools
    "John the Ripper", "Hashcat", "Aircrack", "Wireshark", "Nmap", "Metasploit", "Burp Suite", "OWASP ZAP",
    
    # System utilities that can bypass security
    "Process Monitor", "Process Explorer", "Sysinternals", "Balena Etcher",
    
    # Cryptocurrency/Mining software
    "Bitcoin", "Ethereum", "Mining", "Miner", "NiceHash", "Claymore", "Phoenix Miner",
    
    # Potentially unwanted programs
    "Adware", "Toolbar", "Browser Helper", "PC Optimizer", "Registry Cleaner", "Driver Updater",
    
    # Gaming/Entertainment (if restricted)
    "Steam", "Epic Games", "Discord", "Twitch", "OBS Studio", "Netflix"
)

try {
    Write-Host "Searching for potentially insecure software..." -ForegroundColor Green
    
    $allResults = @()
    $searchedApps = @()
    
    foreach ($pattern in $InsecureSoftwarePatterns) {
        Write-Host "Searching for: $pattern" -ForegroundColor Cyan
        
        try {
            $apps = Get-MgDeviceManagementDetectedApp -Filter "contains(displayName,'$pattern')" -All -ErrorAction SilentlyContinue
            $searchedApps += $apps
        } catch {
            Write-Host "  Warning: Could not search for $pattern" -ForegroundColor Yellow
        }
    }
    
    # Remove duplicates and filter out legitimate software
    $excludePatterns = @("Microsoft Teams", "MSTeams", "Teams", "Microsoft", "Windows", "Office", "Outlook", "OneDrive", "SharePoint")
    
    $filteredApps = $searchedApps | Where-Object { 
        $appName = $_.DisplayName
        $shouldExclude = $false
        foreach ($exclude in $excludePatterns) {
            if ($appName -like "*$exclude*") {
                $shouldExclude = $true
                break
            }
        }
        -not $shouldExclude
    }
    
    $uniqueApps = $filteredApps | Sort-Object Id -Unique
    
    if ($uniqueApps.Count -eq 0) {
        Write-Host "No potentially insecure software found." -ForegroundColor Green
        exit
    }
    
    Write-Host "Found $($uniqueApps.Count) potentially problematic application(s)" -ForegroundColor Yellow
    
    foreach ($app in $uniqueApps) {
        Write-Host "Processing: $($app.DisplayName)" -ForegroundColor Cyan
        
        try {
            # Get managed devices where this app is installed
            $managedDevices = Get-MgDeviceManagementDetectedAppManagedDevice -DetectedAppId $app.Id -All -ErrorAction SilentlyContinue
            
            foreach ($deviceRef in $managedDevices) {
                # Get full device details
                $device = Get-MgDeviceManagementManagedDevice -ManagedDeviceId $deviceRef.Id -ErrorAction SilentlyContinue
                
                if ($device) {
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
                    
                    # Categorize the risk
                    $riskCategory = "Unknown"
                    $appName = $app.DisplayName.ToLower()
                    
                    if ($appName -match "vpn|nord|express|cyberghost") { $riskCategory = "Unauthorized VPN" }
                    elseif ($appName -match "tails|whonix") { $riskCategory = "Anonymous Browsing" }
                    elseif ($appName -match "torrent|bittorrent|utorrent") { $riskCategory = "P2P File Sharing" }
                    elseif ($appName -match "teamviewer|anydesk|vnc|rdp") { $riskCategory = "Remote Access" }
                    elseif ($appName -match "wireshark|nmap|metasploit|burp") { $riskCategory = "Security/Hacking Tools" }
                    elseif ($appName -match "bitcoin|ethereum|mining|miner") { $riskCategory = "Cryptocurrency" }
                    elseif ($appName -match "steam|discord|netflix") { $riskCategory = "Entertainment/Gaming" }
                    
                    $result = [PSCustomObject]@{
                        'Risk Category' = $riskCategory
                        'App Name' = $app.DisplayName
                        'App Version' = $app.Version
                        'Device Name' = $device.DeviceName
                        'Primary User' = $primaryUser
                        'OS' = $device.OperatingSystem
                        'Last Sync' = $device.LastSyncDateTime
                        'Compliance' = $device.ComplianceState
                    }
                    
                    $allResults += $result
                }
            }
        } catch {
            Write-Host "  Error processing $($app.DisplayName): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # Display results
    if ($allResults.Count -gt 0) {
        Write-Host "`nPotentially Insecure Software Found:" -ForegroundColor Red
        Write-Host "=" * 80 -ForegroundColor Red
        
        # Group by risk category
        $groupedResults = $allResults | Group-Object 'Risk Category' | Sort-Object Name
        
        foreach ($group in $groupedResults) {
            Write-Host "`n$($group.Name) - $($group.Count) installation(s):" -ForegroundColor Yellow
            $group.Group | Format-Table 'App Name', 'Device Name', 'Primary User', 'OS' -AutoSize
        }
        
        # Export to CSV
        $csvPath = "InsecureSoftware-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
        $allResults | Export-Csv -Path $csvPath -NoTypeInformation
        Write-Host "`nDetailed results exported to: $csvPath" -ForegroundColor Yellow
        
        # Summary
        $riskSummary = $allResults | Group-Object 'Risk Category' | Sort-Object Count -Descending
        Write-Host "`nRisk Summary:" -ForegroundColor Red
        foreach ($risk in $riskSummary) {
            Write-Host "- $($risk.Name): $($risk.Count) installations" -ForegroundColor Red
        }
        
        Write-Host "`nTotal: $($allResults.Count) potentially problematic installations found" -ForegroundColor Red
        
    } else {
        Write-Host "No devices found with potentially insecure software." -ForegroundColor Green
    }
    
} catch {
    Write-Error "Error occurred: $($_.Exception.Message)"
} finally {
    # Disconnect from Graph
    Disconnect-MgGraph
    Write-Host "`nDisconnected from Microsoft Graph" -ForegroundColor Gray
}