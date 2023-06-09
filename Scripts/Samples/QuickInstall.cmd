@if not defined debug echo off

robocopy /e %~dp0 "C:\Program Files\2Pint Software\iPXE AnywhereWS\Scripts" %*

:: if not exists "C:\Program Files\2Pint Software\iPXE AnywhereWS\Scripts\Custom\Constants.ps1" copy %~dp0\custom\constants.ps1 "C:\Program Files\2Pint Software\iPXE AnywhereWS\Scripts\Custom\Constants.ps1"
