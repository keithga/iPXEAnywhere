<#
.Synopsis
   iPXEAnywhere Powershell Boot Handler
.DESCRIPTION
   iPXEAnywhere boot service, Used to display 1st menu after Device Authentication.
.EXAMPLE
   & .\iPXEBoot.ps1 - Called from within the iPXEAnywhere Service   
#>
[cmdletbinding(DefaultParameterSetName='default')]
Param
(
    
    [object] $Machine,
    [object] $RequestStatusInfo,
    [object] $RequestNetworkInfo,

    [hashtable] $QueryParams,
    [hashtable] $PostParams,
    [string] $Paramdata,

    # The Following is only Applicable with StifleR intergration. 
    [Parameter(ParameterSetName = 'StifleR')]
    $TargetLocation,
    [Parameter(ParameterSetName = 'StifleR')]
    $TargetNetworkGroup,
    [Parameter(ParameterSetName = 'StifleR')]
    $TargetNetwork,
    [Parameter(ParameterSetName = 'StifleR')]
    $TargetMachineKeyValues,
    [Parameter(ParameterSetName = 'StifleR')]
    $DeployMachineKeyValues,
    [Parameter(ParameterSetName = 'StifleR')]
    $DeployLocation,
    [Parameter(ParameterSetName = 'StifleR')]
    $DeployNetworkGroup,
    [Parameter(ParameterSetName = 'StifleR')]
    $DeployNetwork,

    [Parameter(ValueFromRemainingArguments)]
    $RemainingDoNotUse 
)

#region Initialize
#######################################

$MyScriptRoot = $PSScriptRoot
if ( [string]::IsNullOrEmpty($PSScriptRoot) ) { 
    # We are running in iPXEAnywhereWS. Get Full Path of this script directory from host.
    $MyScriptRoot = [iPXEAnywhere.Service.Configuration]::DeviceAuthenticationScript.Directory
}

if ( test-path $MyScriptRoot\..\Custom\Constants.ps1 ) {
    try {
        . $MyScriptRoot\..\Custom\Constants.ps1
    }
    catch { 
        write-warning "Failed to run .\Custom\Constants.ps1"
        $_ | out-string | write-warning
    }
}

#endregion

#region Debugging
#######################################

if ( test-path $MyScriptRoot\..\Library\2PintDebugging.ps1 ) {
    . $MyScriptRoot\..\Library\2PintDebugging.ps1

    if ( $VerbosePreference -eq 'continue' ) {
        Enable-HostOverride  #redirect Write-Host,Write-Verbose... commands to iPXEWS Log 

        Write-2PintDumpAllVariables
    }

}

#endregion

###############################################################################

write-verbose "START iPXEBoot:[$($RequestStatusinfo.ApprovedBy)]"

#region Enable any network security exceptions like 802.1x

$RevokeiPXECommands = ""
if ( test-path function:\revoke-MyNetworkSecurity ) {
    write-verbose "Disable Port Based Network Security"
    try {
        $RevokeiPXECommands = Revoke-MyNetworkSecurity -RequestStatusInfo $RequestStatusInfo -deployNetwork $DeployNetwork
    }
    catch {
        write-Warning "Failed to Revoke Network Security"
        $_ | out-string | write-warning
    }
}

#endregion

#region Get Defaults for this machine 

$DefaultMenu = 'win10prod'
$ForceMenuDefault = $null

if ( test-path $MyScriptRoot\..\Custom\DeviceList.txt ) {

    $DeviceList = import-csv -path $MyScriptRoot\..\Custom\DeviceList.txt -Delimiter "`t" 

    Foreach ( $device in $DeviceList ) {
    
        # $device | out-string | write-verbose

        if ( ($postParams['make'] -match $device.Make ) -and ($postParams['model'] -match $Device.model ) ) {
            write-verbose "found: $($device.Make) $($device.model)"
            $device | out-string | Write-verbose

            $DefaultMenu = $Device.Default 
            $ForceDefault = $Device.Force

            break
        }
    }

}

#endregion

#region Defaults for testing
#######################################
 
if ( $PostParams['asset'] -eq '3992-462b-f644-8b6a-835b-ba6c-01' ) {
    $ForceMenuDefault = 'win10prod' # WIn 10 Prod
}
elseif ( $PostParams['asset'] -eq '3992-462b-f644-8b6a-835b-ba6c-02' ) {
    $ForceMenuDefault = 'win10preprod' # WIn 10 Pre-Prod
}
elseif ( $PostParams['asset'] -eq '3992-462b-f644-8b6a-835b-ba6c-03' ) {
    $ForceMenuDefault = 'win11prod' # Win 11 Prod
}
elseif ( $PostParams['asset'] -eq '3992-462b-f644-8b6a-835b-ba6c-04' ) {
    $ForceMenuDefault = 'win11preprod' # Win 11 Pre-Prod
}

#endregion

#region Display extended menu options 

$xm = $false

$BCEnabled = 1

if($arrayOfTrustedSubnets.Contains($DeployNetwork.NetworkId.ToString()) ) {
    Write-Host "Menu Mode: Trusted Build Center $($DeployNetwork.NetworkId.ToString())"
    $xm = $true
}

if(( $RequestStatusinfo.ApprovedBy -match 'ImgAdmin')) {
    Write-Host "Menu Mode: Imaging administrators $($PostParams['authvalue'])"
    $xm = $true
}

#endregion

#######################################

$RequiredVersion = '1.21.1+${sp}(gff0f8)'

$Menu = @"
#!ipxe
#default section to set some key variable such as pictures etc.

set peerdist $BCEnabled
#$peerdedicatehost

#set debug true

#This calls the default param set named paramdata used in posts
$Paramdata

### REMOVE IN FUTURE - BUGBUG
param --params paramdata peerdist `${peerdist}

###########################
$RevokeiPXECommands

###########################

echo Check Version ( filename implies ipxe boot not USB boot ) ...
# isset `${filename} && goto versiongood
set sp:hex 20 && set sp `${sp:string}
iseq `${version} $RequiredVersion && goto versiongood || echo Invalid iPXE Version
echo %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
echo `${manufacturer:hexhyp}
echo `${manufacturer} `${model}
echo Currently: `${version}
echo Should Be: $RequiredVersion
echo Please Update your USB Stick with the latest iPXE Version
echo %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# prompt Press any key to continue
# exit 1
sleep 15
:versiongood

###########################

$(if ($ForceMenuDefault) {"goto $ForceMenuDefault"})

:start
menu Please choose OS version for production deployment [$env:computerName]
item --gap Available Operating Systems
item
item --key a win10prod Windows 10 22H2
$(if ($xm) {'#item --key b win11prod Windows 11 22H2'})
item
$(if ($xm) {'item --key q cmprod List other available task sequences'})
$(if ($xm) {'item'})
$(if ($xm) {'item --gap Other Boot Options'})
$(if ($xm) {'item'})
item --key u ipxeusb   Create or update iPXE USB
item --key r reset     Reset computer in ipxe DB - Force Login
item reboot            Reboot the computer
item --key x exit      Exit and continue boot order

choose --default $($DefaultMenu.ToLower()) --timeout 30000 target && goto `${target} || goto exit

:win10prod
chain --timeout 360000 `${wsurl}/script?scriptname=configmgr/win10prod.ps1##params=paramdata || shell

:win11prod
chain --timeout 360000 `${wsurl}/script?scriptname=configmgr/win11prod.ps1##params=paramdata || shell

:win10preprod
chain --timeout 360000 `${wsurl}/script?scriptname=configmgr/win10preprod.ps1##params=paramdata || shell

:win11preprod
chain --timeout 360000 `${wsurl}/script?scriptname=configmgr/win1pre1prod.ps1##params=paramdata || shell

:cmprod
chain `${wsurl}/script?scriptname=configmgr/cm.ps1##params=paramdata || shell

goto start

:ipxeusb
chain --timeout 360000 `${wsurl}/script?scriptname=custom/winpe.ps1##params=paramdata || shell

:reset
initrd `${wsurl}/report/deployend##params=paramdata
reboot

:reboot
reboot

:exit
initrd `${wsurl}/report/deployend##params=paramdata
exit 1
"@

# $Menu | write-verbose

$Menu | write-output
