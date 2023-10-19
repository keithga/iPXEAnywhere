param(
    $Machine, 
    $RequestStatusInfo, 
    $RequestNetworkInfo, 
    $Machineinformation, 
    $QueryParams, 
    $PostParams, 
    $Paramdata, 
    $DeployMachineKeyValues,
    $TargetMachineKeyValues,
    $DeployLocation,
    $DeployNetworkGroup,
    $DeployNetwork,
    $TargetLocation,
    $TargetNetworkGroup,
    $TargetNetwork
)


#GUID based UUID property in DB, so change to string based for PS to understand
[string]$SMBIOSGUID = $Machine.UUID.ToString()
[string]$MAC = $RequestStatusInfo.DeployMAC.ToString()

$verifyScriptPath = "D:\Apps\2Pint Software\iPXE AnywhereWS\Scripts"
$CMVerifyFile = "$verifyScriptPath\ConfigMgr\Shared\Verify-CMObjects.ps1" 

#Load the main CM functions
. $CMVerifyFile

#This functions sets the object to unknown
$verified = Verify-CMObjectUnknwon -SMBIOSGUID $SMBIOSGUID -MACAddress $MAC
if($verified -is [string])
{
    #Failed to delete the objects, this returns an iPXE string/script
    return $verified
}
elseif($verified -eq $true)
{
    #Success, we can boot this device
}
else
{
    #Failed here but we dont know why
    $errorData = @"
#!ipxe
echo Failed to execute verification
shell
"@
    return $errorData;
}


#Win11 Prod Hidden Deployment to Unknown Objects collection
$TargetOfferId = "MEM24020"

$Paramdata = $Paramdata + 
@"

param --params paramdata nomenu true
#This selects what gets deployed
#Note: The machine still has to have deployment in offerid targetting the device!!!
param --params paramdata offerid $TargetOfferId
#Prompt or no prompt
param --params paramdata mandatory true

"@


$menu = @"
#!ipxe

#set debug true
isset `${peerdist} || set peerdist 1
#This calls the default param set named paramdata used in posts
$Paramdata

#Set the override to allow the 2PXE server to bypess the WS execution
param --params paramdata wsoverride 1 ||

#get existing object

#Call Central site
#Call primary site and wait


#get all params from CM

#get all params from some other DB

#add to db

#wipe record - call 





#build as new system
#If one wanted you could provide a menu of all servers to select from here.
set completeurl `${pxeurl}2PXE/boot##params=paramdata
echo `${completeurl}
chain `${completeurl} || shell

"@



return $menu