<#
.SYNOPSIS
    Uninstall Private Internet Access VPN via Intune
.DESCRIPTION
    Removes PIA VPN client using winget with proper logging for Intune
#>

# Set execution policy and create log directory
$LogPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
$LogFile = "$LogPath\PIA-Uninstall.log"

if (!(Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force
}

function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp - $Message" | Out-File -FilePath $LogFile -Append
    Write-Host $Message
}

try {
    Write-Log "Starting Private Internet Access VPN uninstall"
    
    # Check if winget is available
    if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Log "ERROR: winget not found"
        exit 1
    }
    
    # Search for PIA VPN
    $piaCheck = winget list --name "Private Internet Access" --accept-source-agreements 2>$null
    
    if ($piaCheck -match "Private Internet Access") {
        Write-Log "Found Private Internet Access VPN - proceeding with uninstall"
        
        # Uninstall PIA VPN
        $result = winget uninstall --name "Private Internet Access" --accept-source-agreements --disable-interactivity --silent
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "SUCCESS: Private Internet Access VPN uninstalled"
            exit 0
        } else {
            Write-Log "WARNING: Primary uninstall failed, trying alternative method"
            $result2 = winget uninstall --id "PrivateInternetAccess.PrivateInternetAccess" --accept-source-agreements --disable-interactivity --silent
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "SUCCESS: PIA VPN uninstalled via alternative method"
                exit 0
            } else {
                Write-Log "ERROR: Both uninstall methods failed. Exit code: $LASTEXITCODE"
                exit 1
            }
        }
    } else {
        Write-Log "INFO: Private Internet Access VPN not found - may already be uninstalled"
        exit 0
    }
} catch {
    Write-Log "ERROR: Script failed with exception: $($_.Exception.Message)"
    exit 1
}