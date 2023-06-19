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

        if ( $LogPath ) {
            remove-item $logPath -ErrorAction SilentlyContinue -Force | Out-Null
            Write-2PintDumpAllVariables $LogPath
        }    }

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

$DefaultMenu = 'win11prod'
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

#region Display extended menu options 

$xm = $false

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

$Menu = @"
#!ipxe
#default section to set some key variable such as pictures etc.

set peerdist $BCEnabled
$peerdedicatehost

#set debug true

#This calls the default param set named paramdata used in posts
$Paramdata

###########################
$RevokeiPXECommands

###########################

$(if ($ForceMenuDefault) {"goto $ForceMenuDefault"})

:start
menu Please choose OS version for production deployment [$env:computerName]
item --gap Available Operating Systems
item
item --key a win10prod Windows 10 22H2
$(if ($xm) {'item --key b win11prod Windows 11 22H2'})
item
$(if ($xm) {'item --key q cmprod List other available task sequences'})
$(if ($xm) {'item'})
$(if ($xm) {'item --gap Other Boot Options'})
$(if ($xm) {'item --key c galaxyprod galaxy - Prod'})
$(if ($xm) {'item --key k galaxypre galaxy - Pre-Prod'})
$(if ($xm) {'item'})
item --key x exit      Exit and continue boot order

choose --default $($DefaultMenu.ToLower()) --timeout 30000 target && goto `${target} || goto exit

:win10prod
chain --timeout 360000 `${wsurl}/script?scriptname=configmgr/win10prod.ps1##params=paramdata || shell

:win11prod
chain --timeout 360000 `${wsurl}/script?scriptname=configmgr/win11prod.ps1##params=paramdata || shell

:cmprod
chain `${wsurl}/script?scriptname=configmgr/cm.ps1##params=paramdata || shell

:galaxyprod
chain `${wsurl}/script?scriptname=custom/galaxyprod.ps1##params=paramdata || shell

:galaxypre
chain `${wsurl}/script?scriptname=custom/galaxypreprod.ps1##params=paramdata || shell

goto start

:reboot
reboot

:exit
# Force iPXE to delete DB Object
initrd `${wsurl}/report/deployend##params=paramdata
exit 1
"@

# $Menu | write-verbose

$Menu | write-output
