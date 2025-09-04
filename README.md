# PowerShell & Microsoft Graph API Scripts Collection

A collection of PowerShell scripts for Microsoft Graph API interactions, Intune management, and system administration tasks.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Authentication](#authentication)
- [Intune Management Scripts](#intune-management-scripts)
- [Security & Compliance Scripts](#security--compliance-scripts)
- [System Administration Scripts](#system-administration-scripts)
- [Usage Examples](#usage-examples)
- [Contributing](#contributing)

## 🔧 Prerequisites

### Required Modules
```powershell
# Install Microsoft Graph PowerShell SDK
Install-Module Microsoft.Graph -Force -AllowClobber

# Install specific Graph modules
Install-Module Microsoft.Graph.Authentication
Install-Module Microsoft.Graph.DeviceManagement
Install-Module Microsoft.Graph.Users
```

### Required Permissions
Your Azure AD application or user account needs the following Microsoft Graph permissions:

- `DeviceManagementManagedDevices.Read.All`
- `DeviceManagementApps.Read.All`
- `User.Read.All`
- `Directory.Read.All`

## 🔐 Authentication

### Connect to Microsoft Graph
```powershell
# Interactive authentication
Connect-MgGraph -Scopes @(
    "DeviceManagementManagedDevices.Read.All",
    "DeviceManagementApps.Read.All",
    "User.Read.All"
)

# Disconnect when finished
Disconnect-MgGraph
```

## 💻 Intune Management Scripts

### 1. Software Discovery Scripts

#### Find VPN Applications
**File:** `Get-VPN-Applications.ps1`

Searches for any application containing "VPN" in discovered apps and reports device names and users.

```powershell
.\Get-VPN-Applications.ps1
```

#### Find Specific Applications
**Files:** 
- `Get-PIA-Installations.ps1` - Private Internet Access VPN
- `Get-NordVPN-Installations.ps1` - NordVPN installations
- `Get-Netskope-AWS-Machines.ps1` - Netskope on AWS machines only
- `Get-TorBrowser-Installations.ps1` - Tor Browser installations

#### Find Insecure Software
**File:** `Get-InsecureSoftware-Installations.ps1`

Comprehensive scan for potentially problematic software including:
- Unauthorized VPN clients
- P2P file sharing applications
- Remote access tools
- Cryptocurrency mining software
- Security/penetration testing tools

```powershell
.\Get-InsecureSoftware-Installations.ps1
```

### 2. Software Removal Scripts

#### Uninstall Private Internet Access VPN
**File:** `Uninstall-PIA-VPN.ps1`

Intune-compatible script for removing PIA VPN using winget with comprehensive logging.

**Intune Deployment:**
- Target: **Devices**
- Run as: **System**
- PowerShell execution policy: **Bypass**

```powershell
# Manual execution
.\Uninstall-PIA-VPN.ps1
```

## 🛡️ Security & Compliance Scripts

### Software Compliance Reporting

All discovery scripts generate timestamped CSV reports for compliance tracking:

- Device names and primary users
- Application versions
- Operating system information
- Last sync timestamps
- Compliance status

### Risk Categorization

The insecure software script categorizes findings:
- **Unauthorized VPN** - Personal VPN clients
- **P2P File Sharing** - BitTorrent, uTorrent, etc.
- **Remote Access** - TeamViewer, AnyDesk, etc.
- **Security Tools** - Wireshark, Nmap, etc.
- **Cryptocurrency** - Mining software and wallets
- **Entertainment** - Gaming and streaming applications

## ⚙️ System Administration Scripts

### Active Directory Management

#### Clone User Group Memberships
**Files:** `cloneadDLgroups.ps1`, `cloneadusergroups.ps1`

Clone distribution list and security group memberships from one user to another.

```powershell
# Clone distribution groups
.\cloneadDLgroups.ps1
# Prompts for source and target usernames

# Clone security groups  
.\cloneadusergroups.ps1
# Prompts for source and target usernames
```

#### Door Card Management
**File:** `doorcardupdateV2.ps1`

Updates Active Directory extension attributes for door card access systems. Converts decimal card numbers to hexadecimal format.

```powershell
.\doorcardupdateV2.ps1
# Prompts for username and card number
# Updates extensionattribute5 (decimal) and extensionattribute6 (hex)
```

### Exchange Management

#### Connect to On-Premises Exchange
**File:** `ConnectExchange.ps1`

Establishes PowerShell session to on-premises Exchange server with Kerberos authentication.

```powershell
.\ConnectExchange.ps1
# Prompts for credentials
# Connects to Exchange server for mailbox management
```

### Compliance & Security Monitoring

#### Basic Compliance Check
**File:** `compliancecheck.ps1`

Monitors essential security services and processes:
- Microsoft Defender (MsSense.exe, MsMpEng.exe)
- Netskope (stAgentSvc.exe)  
- Data Loss Prevention (SenseCE.exe)

```powershell
.\compliancecheck.ps1
# Displays color-coded status output
# Creates temporary log file with results
```

#### Enhanced Compliance Check v2
**File:** `compliancecheckv2.ps1`

Advanced compliance monitoring with service restart capabilities:

```powershell
.\compliancecheckv2.ps1 [-NoGUI] [-LogPath "C:\custom\path.log"]

# Features:
# - Automatic service restart attempts
# - Detailed logging with timestamps
# - Process and service monitoring
# - Formatted summary table
# - Exit codes for automation
```

### Hardware Inventory

#### Docking Station Inventory
**File:** `getdockserial.ps1`

Intune-compatible script for collecting docking station information:

```powershell
# Intune deployment settings:
# - Run as System account
# - 64-bit PowerShell
# - No signature check required

# Features:
# - Subnet validation (10.76.212.0/24)
# - Dell WMI integration for WD docking stations
# - Multiple detection methods
# - Central CSV reporting
# - Retry logic with fallback local storage
```

**Data Collected:**
- Computer name, serial, model
- Current user
- Docking station name, model, serial
- Timestamp and script version

### Productivity Tools

#### Keep System Awake
**File:** `keepawake.ps1`

Prevents system sleep/lock by sending non-intrusive keystrokes:

```powershell
.\keepawake.ps1
# Sends Shift+F15 every 59 seconds
# Non-intrusive key combination
# Infinite loop - use Ctrl+C to stop
```

### Environment Setup

#### Claude Code Setup (macOS)
**File:** `setup_claude_code.sh`

Automated setup script for Claude Code environment configuration:

```bash
chmod +x setup_claude_code.sh
./setup_claude_code.sh

# Features:
# - Interactive API key input
# - System certificate export
# - Environment variable configuration
# - Shell profile integration (.zshrc/.bashrc)
# - macOS notification system
# - JAMF deployment compatible
```

**Configuration Sets:**
- ANTHROPIC_BASE_URL and AUTH_TOKEN
- NODE_EXTRA_CA_CERTS for certificate handling
- OpenTelemetry endpoints for monitoring
- Host and user identification

### Windows Update Management

```powershell
# Force install specific KB update
wusa.exe KB5064010.msu /quiet /norestart

# Reset Windows Update components
net stop wuauserv
net stop cryptSvc
net stop bits
net stop msiserver
ren C:\Windows\SoftwareDistribution SoftwareDistribution.old
ren C:\Windows\System32\catroot2 Catroot2.old
net start wuauserv
net start cryptSvc
net start bits
net start msiserver
```

### PowerShell with Graph Module Examples

```powershell
# Get all managed devices
Get-MgDeviceManagementManagedDevice | Select-Object DeviceName, OperatingSystem, LastSyncDateTime

# Find specific detected app
Get-MgDeviceManagementDetectedApp -Filter "contains(displayName,'Chrome')"

# Get user information
Get-MgUser -UserId "user@domain.com" -Property DisplayName,UserPrincipalName,Department
```

## 📊 Usage Examples

### Basic Software Discovery
```powershell
# Connect to Graph
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All","DeviceManagementApps.Read.All"

# Run VPN discovery
.\Get-VPN-Applications.ps1

# Results will be displayed in console and exported to CSV
```

### Intune Software Removal
```powershell
# Deploy via Intune as Device Script
# Or run locally with admin privileges
.\Uninstall-PIA-VPN.ps1
```

### Graph Explorer Queries
For quick lookups without PowerShell:

```
GET https://graph.microsoft.com/beta/deviceManagement/detectedApps?$filter=contains(displayName,'VPN')
```

## 📝 Script Features

### Common Features Across All Scripts
- **Error handling** with try/catch blocks
- **Comprehensive logging** with timestamps
- **CSV export** with timestamped filenames
- **Progress indicators** during execution
- **Automatic module installation** checks
- **Clean disconnect** from Graph API

### Output Formats
- **Console display** with color-coded output
- **CSV files** for reporting and analysis
- **Grouped results** by application or risk category
- **Summary statistics** showing totals and counts

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-script`)
3. Commit your changes (`git commit -am 'Add new script'`)
4. Push to the branch (`git push origin feature/new-script`)
5. Create a Pull Request

### Script Standards
- Include comprehensive error handling
- Add parameter validation
- Include help documentation
- Export results to CSV format
- Use consistent naming conventions
- Add progress indicators for long-running operations

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

These scripts are provided as-is for educational and administrative purposes. Always test scripts in a development environment before deploying to production. Ensure you have appropriate permissions and approval before running security scanning tools in your organization.

## 📞 Support

For issues or questions:
1. Check the script comments for detailed usage instructions
2. Review the error handling output for troubleshooting
3. Ensure all required permissions are granted
4. Verify PowerShell execution policy allows script execution

---

**Last Updated:** September 2025
**PowerShell Version:** 5.1+
**Graph API Version:** v1.0 & beta endpoints
