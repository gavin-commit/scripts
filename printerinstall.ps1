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

          $networkObj = [ipaddress]$networkAddress
          $currentIPObj = [ipaddress]$currentIP

          $mask = [ipaddress]([math]::pow(2, 32) - [math]::pow(2, 32 - $prefixLength))

          if (($currentIPObj.Address -band $mask.Address) -eq ($networkObj.Address -band
  $mask.Address)) {
              $networkFound = $true
              Write-Output "Computer is on allowed network: $network (Current IP: $currentIP)"
              break
          }
      }

      if ($networkFound) { break }
  }

  if ($networkFound) {
      try {
          Write-Output "Installing printer: \\iod179\IOM Printer"

          # Modern approach - Add network printer
          Add-Printer -ConnectionName "\\iod179\IOM Printer"

          # Set as default printer
          $printer = Get-CimInstance -ClassName Win32_Printer | Where-Object {$_.Name -eq
  "\\iod179\IOM Printer"}
          if ($printer) {
              Invoke-CimMethod -InputObject $printer -MethodName SetDefaultPrinter
              Write-Output "Printer installed and set as default successfully"
          }
      }
      catch {
          Write-Error "Failed to install printer: $($_.Exception.Message)"
          exit 1
      }
  } else {
      Write-Output "Computer is not on an allowed network. Skipping printer installation."
      exit 0
  }