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

# Enable Debug Logging
$VerbosePreference = 'continue'

#######################################

# Trusted Subnets, no need to prompt for credentials
$arrayOfTrustedSubnets = @(  
"10.0.1.0"
    )

# Trusted Subnets-limited menu, no need to prompt for credentials
$arrayOfTrustedSubnetsLimitedMenu = @(
"10.0.2.0"
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
"10.0.1.0"

)

function Write-2PintConsole
{
    [cmdletbinding()]
    param(
        [Parameter(Position=0, ValueFromPipeline=$true, Mandatory=$true, ValueFromRemainingArguments=$true)]
        [Alias('Msg')]
        [Alias('Object')]
        [AllowEmptyString()]
        [string]
        ${Message}
    )

    Process {
        foreach ($Msg in $Message ) {
            foreach ( $Line in $Msg -split "\r?\n" ) { 
                echo "echo $Line"
            }
        }
    }
}



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
        user = 'corp\8021xaccount'
        password = 'P@ssw0rd'
        mac = $RequestStatusInfo.DeployMac.ToString() -replace ':','-'
    } | ConvertTo-Json -Compress 
    
    $ErrorOut = $null
    $restOut = ''
    try { 
        $result = Invoke-WebRequest "https://internal8021xapi:443/8021x_mab.pl?POSTDATA=$([uri]::EscapeDataString($Body))" -verbose -UseBasicParsing
        write-verbose "Result back from https://internal8021xapi"
        $result | out-string | write-verbose

        if ( ( $result.StatusCode -ne 200 ) -or ( $result.RawContentLength -ne 1 ) ) { 
            $ErrorOut = $result.content | write-2PintConsole 
        }
        else {
            $restOut = $result.Content
        }
    }
    catch {
        write-warning "Failed to make Web Request to https://internal8021xapi"
        $ErrorOut = $_ | write-2PintConsole 

    }

    #Now output to Console:

    if ( $ErrorOut ) {

         @"

echo ####################################################
echo ####################################################
echo
echo Failure to get MAB 802.1x exception:
echo
$( $ErrorOut -join [environment]::newline )
echo
echo ####################################################
echo ####################################################
prompt --key q Press 'q' to quit && exit || echo continue

"@  | Write-Output

    }
    else { 
 
        @"

set currentnic `${netX/ifname}

echo %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
echo Start MAB Exception process [`${currentnic}] ...
ifstat `${currentnic}
echo %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#ping -c 1 sccmipx2.corp.contoso.com && goto mabdone || echo Unable to ping sccmipx2
#ping -c 1 sccmipx1.corp.contoso.com && goto mabdone || echo Unable to ping sccmipx1

echo Unable to reach SCCMIPX[1|2] Begin Mab Process  `${currentnic}

ifclose `${currentnic}

echo sleep 10 and restart NIC `${currentnic}
sleep 10

:mabretry
ifconf `${currentnic} || goto mabbadnic
iflinkwait --timeout 1000 `${currentnic} || goto mabbadnic

#ping -c 1 sccmipx2.corp.contoso.com && goto mabdone || echo Unable to ping sccmipx2
#ping -c 1 sccmipx1.corp.contoso.com && goto mabdone || echo Unable to ping sccmipx1

ping -c 1 ipxe.corp.contoso.com && goto mabnobypass || goto mabbadnic

:mabbadnic
echo %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
echo %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
echo
echo Unable to reach ipxe.corp.contoso.com. NIC in a bad state.
echo 
echo If this is the first time seeing this error, press ENTER for reset.
echo If the problem persists, shutdown the machine and retry.
echo If the problem STILL persists, take a picture of this screen and escalate.
echo
echo %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
echo %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
ifstat `${currentnic}
prompt --timeout 30000 press return to retry reset
ifclose `${currentnic}
goto mabretry

:mabnobypass
echo %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
echo %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
echo
echo Unable to reach 802.1x protected machine(s).
echo 
echo If this is the first time seeing this error, press ENTER for reset.
echo If the problem persists, try disconnecting the network cable and retry.
echo If the problem persists, shutdown the machine and retry.
echo If the problem STILL persists, take a picture of this screen and escalate.
echo
echo %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
echo %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
ifstat `${currentnic}
prompt --timeout 30000 press return to retry reset
# ifclose `${currentnic}
set completeurl `${pxeurl}2PXE/boot##params=paramdata
echo Boot... `${pxeurl}2PXE/boot##params=paramdata
chain --autofree --replace `${pxeurl}2PXE/boot##params=paramdata || goto mabretry

:mabdone
echo %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
echo Finish Network Reset for 802.1x `${currentnic}
echo MAB DONE!
echo %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

prompt --timeout 30000 press return to FINISH

"@ | write-output

    }

}
