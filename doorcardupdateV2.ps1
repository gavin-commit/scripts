##Attribute update script
##Use at your own risk, nothing at all expressed or implied.
$deriomuser = read-host -prompt "Enter username"
set-aduser -server iod112.mgsops.net -identity $deriomuser -Clear "extensionattribute5"
$dec = read-host -prompt "Enter card number"
set-aduser -server iod112.mgsops.net -identity $deriomuser -Add @{extensionattribute5="$dec"}
$Dec = $Dec/1
$Hex = [System.String]::Format('{0:X}', $dec)
set-aduser -server iod112.mgsops.net -identity $deriomuser -Clear "extensionattribute6"
set-aduser -server iod112.mgsops.net -identity $deriomuser -Add @{extensionattribute6="$Hex"}
.\doorcardupdateV2.ps1
