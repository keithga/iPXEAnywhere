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

    if ( $LogPath ) {
        remove-item $logPath -ErrorAction SilentlyContinue -Force | Out-Null
        Write-2PintDumpAllVariables $LogPath
    }
    
    if ( $VerbosePreference -eq 'continue' ) {
        Enable-HostOverride  #redirect Write-Host,Write-Verbose... commands to iPXEWS Log 
    }
}

#endregion

###############################################################################

write-verbose "START iPXEBoot:[$($PostParams['authmethod'])] Value:[$($PostParams['authvalue'])]"

#######################################

$Menu = @"
#!ipxe
#default section to set some key variable such as pictures etc.

set peerdist $BCEnabled
$peerdedicatehost

#set debug true

#This calls the default param set named paramdata used in posts
$Paramdata

echo DONE
echo DONE
echo DONE
echo DONE
echo DONE
echo DONE

prompt press any key to continue...

echo Force iPXE database object to reset for next boot
imgfetch `${wsurl}/Report/DeployEnd##params=paramdata
echo boot to OS...

chain `${pxeurl}/2PXE/boot##params=paramdata || shell

"@

# $Menu | write-verbose

$Menu | write-output
