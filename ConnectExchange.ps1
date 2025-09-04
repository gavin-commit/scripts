#Connect to On-prem Exchange

#$opexch = read-host -prompt "Enter Exchange Server (der0353 or iob0290)"
$UserCredential = Get-Credential
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://der3510/PowerShell/ -Authentication Kerberos -Credential $UserCredential
Import-PSSession $session -DisableNameChecking -allowclobber
