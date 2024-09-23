<# 
    2Pint functions to Verify the CM Objects Status
    Version:        1.0
    Author:         @ 2Pint Software
    Creation Date:  2023-02-03
    Purpose/Change: Initial script development


#>

Function Verify-CMObjectUnknwon {
    <#
.SYNOPSIS
  Queries the CM DB and returns

.DESCRIPTION
  Queries a SQL database and returs the result

.PARAMETER SQLServerFQDN
    FQDN for the CM SQL server
    cmsql.contoso.org
    If not specified the value in CMServerFQDN will be used for SQL queries.

.PARAMETER SiteDB
    Name of the site DB
    
.INPUTS
    Not much

.OUTPUTS
    A string of "OK" if all is OK

.NOTES
  Version:        1.0
  Author:         @ 2Pint Software
  Creation Date:  2023-02-07
  Purpose/Change: Initial script development

.EXAMPLE
  
#>
    Param(
        [Parameter(Mandatory = $true)][string]$SMBIOSGUID,
        [Parameter(Mandatory = $true)][string]$MACAddress
    )
    Process {

                $adminsvc = "sccmsvp1.generic.bank.corp";
                $SQLServerFQDN = "SCCMCASSQL.generic.bank.corp";
                $SiteDB = "CM_MEM";
                $SiteCode = "MEM";
                $scriptPath = "D:\Apps\2Pint Software\iPXE AnywhereWS\Scripts"

                $CMFile = "$scriptPath\ConfigMgr\Shared\Manage-CMObjects.ps1" 

                if((Test-Path $CMFile) -eq $false)
                {
                    throw [System.IO.FileNotFoundException] "Could not find: $CMFile"
                }

                #Load the main CM functions
                . $CMFile

                $devicelookupSMBIOS = Get-CMObject -KeyIdentifier "SMBIOS" -Value "$SMBIOSGUID" -CMServerFQDN $adminsvc -SQLServerFQDN $SQLServerFQDN -SiteDB $SiteDB -SiteCode $SiteCode -UseWMI
                $devicelookupMAC = Get-CMObject -KeyIdentifier "MACAddress" -Value "$MACAddress" -CMServerFQDN $adminsvc -SQLServerFQDN $SQLServerFQDN -SiteDB $SiteDB -SiteCode $SiteCode -UseWMI


                if(($devicelookupMAC -eq $null) -or ($devicelookupSMBIOS -eq $null))
                {
                    #Failure
                    $errorData = @"
#!ipxe
echo Failed to query for records!
shell
"@
                    return $errorData;

                }
                #elseif(($devicelookupMAC -eq $false) -and ($devicelookupSMBIOS -eq $false))
                elseif($devicelookupSMBIOS -eq $false)
                {
                    # No record to delete return $true
                    return $true
                }
                elseif(((($devicelookupMAC -is [array]) -eq $false) -and (($devicelookupMAC -is [array]) -eq $false) -and ($devicelookupSMBIOS.ResourceId -eq $devicelookupMAC.ResourceId)) -or ($devicelookupSMBIOS.ResourceID -and $devicelookupMAC -eq $false))
                {
                    #Single reuturn from both resources that matches
                    $UUID = $devicelookupSMBIOS.SMSUniqueIdentifier.ToString();
                    #This means we dont have any client in there with the UUID or MAC, good to go, machine is unknown
                    $removeRecord = Remove-CMObject -KeyIdentifier UUID -Value $UUID -UseWMI -CMServerFQDN $adminsvc -SQLServerFQDN $SQLServerFQDN -SiteDB $SiteDB -SiteCode $SiteCode
                    #"Remove-CMObject -KeyIdentifier UUID -Value $UUID -UseWMI -CMServerFQDN $adminsvc -SQLServerFQDN $SQLServerFQDN -SiteDB $SiteDB -SiteCode $SiteCode" | out-file "c:\temp\ws\cmd.txt"
                    if($removeRecord -eq $true)
                    {
                        #Success
                        return $true
                    }
                    else
                    {
                        $errorData = @"
#!ipxe
echo Failed to delete the record
shell
"@

                        return $errorData;
                    }
                }
                elseif(($devicelookupSMBIOS[0].ResourceId -eq $null) -and ($devicelookupMAC[0].ResourceId -eq $null))
                {
                            $errorData = @"
#!ipxe
echo Too many records to deal with!
echo BIOS lookup found: $($devicelookupSMBIOS)
echo Mac lookup found: $($devicelookupMAC)
echo Please contact the Configuration Manager team with these details
shell
"@

                        return $errorData;
                }
                else
                {
                    if(($devicelookupSMBIOS.Count -eq 1) -and ($devicelookupMAC.Count -eq 1))
                    {
                        #Two conflicting records
                    }


                     $errorData = @"
#!ipxe
echo Resource ID's usings the same GUID: $($devicelookupSMBIOS.Count) ($SMBIOSGUID)
echo Resource ID's usings the MAC: $($devicelookupMAC.Count) ($MACAddress)
echo
echo First entries:
echo SMBIOS - $($devicelookupSMBIOS[0].ResourceId) - $($devicelookupSMBIOS[0].Name)
echo MAC - $($devicelookupMAC[0].ResourceId) - $($devicelookupMAC[0].Name)
shell
"@

                    return $errorData;
                    #Compare if SMBIOS entry is also the MAC entry
                    #If so, safe to whack it safely, if not, we return a screen
                    #Device is in DB, clear it Out

                }

    }
}
