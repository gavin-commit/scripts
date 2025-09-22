# Check if computer is on the correct networks
  $allowedNetworks = @("10.76.212.0/24", "10.76.213.0/24")
  $networkFound = $false

  # Get all network adapters with IP addresses
  $networkAdapters = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne
  "127.0.0.1" }

  foreach ($adapter in $networkAdapters) {
      $currentIP = $adapter.IPAddress

      foreach ($network in $allowedNetworks) {
          $networkAddress = $network.Split('/')[0]
          $prefixLength = [int]$network.Split('/')[1]

          # Convert to network object for comparison
          $networkObj = [ipaddress]$networkAddress
          $currentIPObj = [ipaddress]$currentIP

          # Calculate network mask
          $mask = [ipaddress]([math]::pow(2, 32) - [math]::pow(2, 32 - $prefixLength))

          # Check if current IP is in the allowed network
          if (($currentIPObj.Address -band $mask.Address) -eq ($networkObj.Address -band
  $mask.Address)) {
              $networkFound = $true
              Write-Host "Computer is on allowed network: $network (Current IP: $currentIP)"
              break
          }
      }

      if ($networkFound) { break }
  }

  if ($networkFound) {
      try {
          Write-Host "Installing printer: \\iod179\IOM Printer"

          # Install printer
          rundll32 printui.dll,PrintUIEntry /in /n "\\iod179\IOM Printer"
          Start-Sleep -Seconds 5

          # Set as default
          rundll32 printui.dll,PrintUIEntry /y /n "\\iod179\IOM Printer"

          Write-Host "Printer installed and set as default successfully"
      }
      catch {
          Write-Error "Failed to install printer: $($_.Exception.Message)"
      }
  } else {
      Write-Host "Computer is not on an allowed network. Skipping printer installation."
  }