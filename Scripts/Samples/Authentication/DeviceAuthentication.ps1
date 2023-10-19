<#
.Synopsis
   iPXEAnywhere Powershell Authentication Handler
.DESCRIPTION
   iPXEAnywhere Authentication service, used to handle Device Authentication
.EXAMPLE
   & .\DeviceAuthentication.ps1 - Called from within the iPXEAnywhere Service 
.NOTES
    MUST return either the $RequestStatusInfo object, or a iPXE script as a string.
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
    . $MyScriptRoot\..\Custom\Constants.ps1
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

write-verbose "START iPXE Device Authentication:[$($PostParams['authmethod'])] Value:[$($PostParams['authvalue'])]"

#region No Auth 
#######################################

$defaultMenu = 'retry'
if ( $ADLoginCode) {
    $defaultMenu = 'user'
}
elseif ( $LoginQRCode) {
    $defaultMenu = 'qr'
}
elseif ( $SecretPin ) {
    $defaultMenu = 'pin'    
}
else {
    Write-Host "DeviceAuthentication Finish: No Auth required"
    $RequestStatusInfo.Approved = $true;
    $RequestStatusInfo.ApprovedBy = "NoAuth";
    return $RequestStatusInfo   
}

#endregion

#region iPXE Regression Testing and Buildout Override...
#######################################
 
$bootOverride = $null
if ( $PostParams['asset'] -eq '3992-462b-f644-8b6a-835b-ba6c-01' ) {
    $bootOverride = 'MEM00101' # WIn 10 Prod
}
elseif ( $PostParams['asset'] -eq '3992-462b-f644-8b6a-835b-ba6c-02' ) {
    $bootOverride = 'MEM00110' # WIn 10 Pre-Prod
}
elseif ( $PostParams['asset'] -eq '3992-462b-f644-8b6a-835b-ba6c-03' ) {
    $bootOverride = 'MEM00111' # Win 11 Prod
}
elseif ( $PostParams['asset'] -eq '3992-462b-f644-8b6a-835b-ba6c-04' ) {
    $bootOverride = 'MEM00110' # Win 11 Pre-Prod
}
elseif ( ($PostParams['asset'] -eq 'e210cac7-c0be-4e6b-bcc3-9d57cd7181f3' ) -and ( [datetime]::now -lt ([datetime]'9/11/2023') ) ) {
    $bootOverride = 'MEM00101' # WIn 10 Prod
}
else {
    Write-Warning "Unknown Type"
}
 
if ($bootOverride) {
    Write-Host "DeviceAuthentication Finish: Trusted Machine $($BootOverride)"
    $RequestStatusInfo.Approved = $true
    $RequestStatusInfo.ApprovedBy = "ByPass";
    return $RequestStatusInfo
}

#endregion 

#region is Trusted Network ( No Authentication )
#######################################

$GlobalArrayOfTrustedSubnets = $arrayOfTrustedSubnets + $arrayOfTrustedSubnetsLimitedMenu


if($GlobalArrayOfTrustedSubnets.Contains($DeployNetwork.NetworkId.ToString()) ) {
    Write-Host "DeviceAuthentication Finish: Trusted Build Center $($DeployNetwork.NetworkId.ToString())"
    $RequestStatusInfo.Approved = $true;
    $RequestStatusInfo.ApprovedBy = "BuildCenter";
    return $RequestStatusInfo
}

#endregion

#region Is authorized by Active Directory?
#######################################

if(($PostParams["authmethod"] -match "adurl") -and ($PostParams["authvalue"] -ne $null)) {
    Write-Host "DeviceAuthentication Finish: Truested Build Center $($PostParams['authvalue'])"
    $RequestStatusInfo.Approved = $true;
    $RequestStatusInfo.ApprovedBy = $PostParams["authvalue"];
    return $RequestStatusInfo
}

#endregion

#region Is authorized by PIN?
#######################################

if(($PostParams["authmethod"] -eq 'pin') -and ($SecretPin -ne $null) -and ($PostParams["authvalue"] -eq $secretPin)) {
    Write-Host "DeviceAuthentication Finish: Secret Pin"
    $RequestStatusInfo.Approved = $true;
    $RequestStatusInfo.ApprovedBy = "SecretPin";
    return $RequestStatusInfo
}

#endregion


###############################################################################

$Menu = @"
#!ipxe

#set debug true

#This calls the default param set named paramdata used in posts
$Paramdata

$(if ($ForceADAuth -and $ADLoginCode) {'goto user'})

:start
menu iPXE Anywhere authentication menu
item --gap --          -------------------------------- Please choose how to authenticate ------------------------  
$(if ($LoginQRCode) { 'item --key q qr        Use a QR code'})
$(if ($SecretPin)   { 'item --key p pin       Use a pin'})
$(if ($ADLoginCode) { 'item --key u user      Username and password' })
item --gap --          --------------------------------                Advanced           ------------------------
item --key r retry     Refresh Device Authentication request
item --key c config    Run the config tool
item shell             Drop to the iPXE shell
item reboot            Reboot the computer
item
item --key x exit      Exit and continue boot order
choose --timeout 30000 --default $defaultMenu selected || goto cancel
goto `${selected}

:retry
echo `${pxeurl}/2PXE/boot##params=paramdata
chain `${pxeurl}/2PXE/boot##params=paramdata || shell

:shell
echo Type exit to return to menu
shell
goto start

:config 
config
goto start

:pin
echo -n Please provide a pin:
read authvalue
param --params paramdata authmethod pin
param --params paramdata authvalue `${authvalue}
chain `${pxeurl}/2PXE/boot##params=paramdata || shell

:reboot
reboot

:exit
exit 1

$LoginQRCode

$AdLoginCode 

"@

# $menu | Write-Verbose

$menu | Write-Output