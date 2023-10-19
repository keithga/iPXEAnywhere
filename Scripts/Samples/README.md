# iPXEAnywhere Examples for Customer

[Keith Garner](keithg@2pintsoftware.com)
Summer 2023

# iPXEAnywhere changes from default examples

## DeviceAuthenticaion.ps1

* Customer requested all constants be stored in a single `Contstants.ps1` file for easy editing.
* Customer requested the ability to login using Active Directory. See _NewGroupValidation.ps1 to see how this is prepared on a local IIS server. This script will attempt to validate against protected resources on a local IIS Server.
* Established a Login override option for machines with a custom Asset Tag in the BIOS. Can be set by Hyper-V. Used for automated testing.
* Customer requested the ability to override the menu prompt if the computer was in a designated Subnet. eg Build Center

## Manage-CMObjects.ps1 and Verify_CMObjects.ps1

* Some bug fixes to address timeouts in large environments.

## iPXEBoot.ps1

* Customer has 802.1x security. Both iPXE servers are behind a network Load Balancer, which is unprotected. function `Revoke-MyNetworkSecurity` needs to request a MAB exception for the client from an internal RestAPI server, and then tell the client to re-authenticate. 
* FInal boot menu can be dependent on WHO is logged in, and where the machine is located. the XM (extended menu) is shown when one of these conditions are true. 

## Constants.ps1

* $ADLoginCode contains the code necessary to validate the user against Active Directory. 
  - Control.txt - is used to validate the password is correct.
  - ImgAdmin.txt - is used to validate if the user is part of the Imaging Administrators Team (Full permissions).
  - FieldTech.txt - is used to validate if the user is one of the field techs (Limited permissions)
* If the user types in the wrong password, then control.txt will fail. 

* There is extensive code at the bottom of the script to address 802.1x exceptions from the client side.  The customer's environment is very sensitive, and sometimes we need to perform an iPXE network driver reset on the client side to force the network switch to re-evaluate it's policy to verify the 802.1x exceptions have been processed. correctly. 

-k
