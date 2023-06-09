<#
.SYNOPSIS
    Custom Override Values
.DESCRIPTION
    Edit custom values here per customer
.NOTES
    Per Customer
#>

[cmdletbinding()]
param()

#######################################

# Path to dump variables for debugging
# $logPath = 'C:\programdata\2Pint Software\iPXEWS\iPXEBoot.log'

# Enable Debug Logging
# $VerbosePreference = 'continue'

#######################################

# Trusted Subnets, no need to prompt for credentials
$arrayOfTrustedSubnets = @(  
    "10.123.0.0"    
    )

#######################################

# Menu Types

$LoginQRCode = $null
$SecretPin = $null
$ForceADAuth = $true

# Authorization URL is same server as IPXE, with different port
$AuthURL = 'https://${username:uristring}:${password:uristring}@' + ([uri]$postparams['pxeurl']).Host

$ADLoginCode = @"

:user
login || goto start

echo Validate Credentials
imgfetch $AuthURL/2PintAuth/Control.txt || goto badcred
echo Credentials valid, check ACLs...

:cred1
imgfetch $AuthURL/2PintAuth/ImgAdmin.txt || goto cred2
param --params paramdata authmethod adurl
param --params paramdata authvalue `${authvalue} ImgAdmin

:cred2
imgfetch $AuthURL/2PintAuth/FieldTech.txt || goto cred3
param --params paramdata authmethod adurl
param --params paramdata authvalue `${authvalue} FieldTech

:cred3
:credfinal
chain `${pxeurl}/2PXE/boot##params=paramdata || shell

:badcred
echo Unable to validate Credentials,
echo If 'Permission denied' is shown above, then credentials may be bad.
prompt press any key to try again...
goto user
"@

#######################################

# Subnets not managed by 802.1x
$arrayOfNon802x1Subnets = @(
    "10.0.0.0"        
)

# Custom handler for 802.1x exceptions
function revoke-MyNetworkSecurity {
    [cmdletbinding()]
    param( $RequestStatusInfo, $DeployNetwork )

    "start MAB Process $( $RequestStatusInfo.DeployMac.ToString() )" | write-verbose

    if($arrayOfNon802x1Subnets.Contains($DeployNetwork.NetworkId.ToString()) ) {
        write-verbose "Device is not on an 802.1x network exit. $($DeployNetwork.NetworkId.ToString())"
        return ""
    }

    $body = @{
        user = 'XXXX'
        password = 'XXXX'
        mac = $RequestStatusInfo.DeployMac.ToString() -replace ':','-'
    } | ConvertTo-Json -Compress 
    
    try { 
       $result = Invoke-WebRequest "https://InternalSite.local:8443/auto_reimage.pl?POSTDATA=$([uri]::EscapeDataString($Body))" -verbose -UseBasicParsing
       $result | out-string | write-verbose
    }
    catch {
        write-warning "Failed to make Web Request to https://internalsite.local"
        $_ | out-string |write-warning
    }

    #Additional Commands to run: 

    @"

# MAB Testing

echo Reset Network for MAB 802.1x testing
ifclose
ifconf
echo Finish Network Reset for 802.1x

"@ | write-output

}
