import-module activedirectory

$CloneFrom = Read-Host 'User to clone permissions from'
$CloneTO = Read-Host 'User to assign clone permissions to'

Get-ADPrincipalGroupMembership $CloneFrom | where {$_.GroupCategory -eq "Distribution"} | Add-ADGroupMember -Members $CloneTO -PassThru
