import-module activedirectory

$CloneFrom = Read-Host 'User to clone permissions from'
$CloneTO = Read-Host 'User to assign clone permissions to'

Get-ADPrincipalGroupMembership -server iod101 $CloneFrom | where {$_.GroupCategory -eq "Security"} | Add-ADGroupMember -Members $CloneTO | where {$_.name -notlike "support services*"}
