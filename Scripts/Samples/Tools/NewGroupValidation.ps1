<#
.Synopsis
   Build IIS Site for 2Pint Group Validation
.DESCRIPTION
   Create web site for iPXE To validate user credentials.
.EXAMPLE
   Another example of how to use this cmdlet
#>
Param (

    $Site = 'Default Web Site',
    $Name = '2PintAuth'

)

$ErrorActionPreference = 'stop'

#region Prepare Site

$WebSite = Get-Website -Name $site
if ( -not $webSite ) { throw "missing Web Site $Site" }
$WebSite | out-string | Write-Verbose

if ( get-windowsfeature  Web-Windows-Auth | ? InstallState -eq 'Available' ) { 
    write-verbose "install Windows Auth for IIS"

    $result = install-windowsfeature -IncludeAllSubFeature -name  Web-Windows-Auth  
    $result | out-string | Write-Verbose
    if ( $result.RestartNeeded -ne 'No' ) { throw "Installation of Web-Windows-Auth Requires reboot" }

}

#endregion

#region Prepare Root Directory

$WebPath = [environment]::ExpandEnvironmentVariables( ( join-path $WebSite.physicalPath $Name ) ) 
write-verbose "WebPath: $WebPath"

if ( -not ( test-path $WebPath ) ) { 
    new-item -ItemType Directory -Path $WebPath -ErrorAction SilentlyContinue | Write-Verbose 
}

#endregion

#region Set Windows Auth


Write-Verbose "Disable anonymous authentication"
Set-WebConfigurationProperty -Filter '/system.webServer/security/authentication/anonymousAuthentication' -Name Enabled -Value False -PSPath "IIS:\" -Location "$($WebSite.Name)/$Name" -force

Write-Verbose "Enable Windows authentication"
Set-WebConfigurationProperty -Filter "/system.webServer/security/authentication/windowsAuthentication" -Name Enabled -Value True -PSPath "IIS:\" -Location "$($WebSite.Name)/$Name" -force


#endregion

#region Prepare Control Case

Function New-FileWithACL {
    [cmdletbinding()]
    Param ( $path, $Group )
    
    Write-Verbose "Create File [$Path] for group [$Group]"

    remove-item -Path $Path -Force -ErrorAction SilentlyContinue | Write-Verbose

    "Hello World" | Out-File -Encoding ascii -filepath $path -Force

    $ACL = get-acl -Path $Path
    $ACL.SetAccessRuleProtection($True,$True)
    $ACL.SetAccessRule(( New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList ( $Group , 'ReadAndExecute', 'Allow' ) )) | Write-Verbose
    $BuiltInUsers = Get-Acl -Path $Path | foreach-object access | where-object IdentityReference -eq 'BUILTIN\Users'
    foreach ( $user in $BuiltInUsers ) { 
        write-verbose "remove $($User.IdentityReference)"
        $ACL.RemoveAccessRule( $User ) | Write-Verbose 
    }

    Set-ACL -Path $Path -AclObject $ACL | Write-Verbose

}

New-FileWithACL -path $WebPath\Control.txt -Group 'Authenticated Users'
New-FileWithACL -path $WebPath\ImgAdmin.txt -Group 'Domain Admins'
New-FileWithACL -path $WebPath\FieldTech.txt -Group 'Domain Admins'

#endregion
