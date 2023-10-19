function write-2PintDebug {
    [cmdletbinding()]
    param(
        [Parameter(Position=0, ValueFromPipeline=$true, Mandatory=$true, ValueFromRemainingArguments=$true)]
        [Alias('Msg')]
        [Alias('Object')]
        [AllowEmptyString()]
        [string]
        ${Message}
    )

    process {
        foreach ( $Msg in $Message ) {
            try {
                [TwoPint.Logging.Log]::WriteDebug($Msg)
            }
            catch {
                Microsoft.PowerShell.Utility\Write-Debug $Msg              
            }
        }
    }

}

function write-2PintInfo {
    [cmdletbinding()]
    param(
        [Parameter(Position=0, ValueFromPipeline=$true, Mandatory=$true, ValueFromRemainingArguments=$true)]
        [Alias('Msg')]
        [Alias('Object')]
        [AllowEmptyString()]
        [string]
        ${Message}
    )

    process {
        foreach ( $Msg in $Message ) {
            try {
                [TwoPint.Logging.Log]::WriteInfo($Msg)
            }
            catch {
                Microsoft.PowerShell.Utility\Write-Host $Msg              
            }
        }
    }

}

function write-2PintError {
    [cmdletbinding()]
    param(
        [Parameter(Position=0, ValueFromPipeline=$true, Mandatory=$true, ValueFromRemainingArguments=$true)]
        [Alias('Msg')]
        [Alias('Object')]
        [AllowEmptyString()]
        [string]
        ${Message}
    )

    process {
        foreach ( $Msg in $Message ) {
            try {
                [TwoPint.Logging.Log]::WriteError($Msg)
            }
            catch {
                Microsoft.PowerShell.Utility\Write-Error $Msg                
            }
            
        }
    }

}

function write-2PintWarning {
    [cmdletbinding()]
    param(
        [Parameter(Position=0, ValueFromPipeline=$true, Mandatory=$true, ValueFromRemainingArguments=$true)]
        [Alias('Msg')]
        [Alias('Object')]
        [AllowEmptyString()]
        [string]
        ${Message}
    )

    process {
        foreach ( $Msg in $Message ) {
            try {
                [TwoPint.Logging.Log]::WriteWarning($Msg)
            }
            catch {
                Microsoft.PowerShell.Utility\Write-Warning $Msg            
            }

        }
    }

}

function write-2PintVerbose {
    [cmdletbinding()]
    param(
        [Parameter(Position=0, ValueFromPipeline=$true, Mandatory=$true, ValueFromRemainingArguments=$true)]
        [Alias('Msg')]
        [Alias('Object')]
        [AllowEmptyString()]
        [string]
        ${Message}
    )

    process {
        foreach ( $Msg in $Message ) {
            try {
                if ( $VerbosePreference -eq 'continue' ) {
                    [TwoPint.Logging.Log]::WriteInfo($Msg)
                }
            }
            catch {
                Microsoft.PowerShell.Utility\Write-Verbose $Msg            
            }

        }
    }

}

function Write-2PintLog
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

    begin {
        if ( -not $logPath ) { $LogPath = 'c:\windows\temp\iPXEPwsh.log' }
    }
    Process {
        foreach ($item in $Msg ) {
            ( [DateTime]::now.tostring('s') + ': ' + $msg ) | Out-File -Encoding ascii -Append -FilePath $LogPath
        }
    }
}

function Write-2PintDumpAllVariables {
    [cmdletbinding()]
    param( $logPath )

    if ( $DebugPreference -ne 'continue' ) { return }

    ('************* Machine') | write-host
    $Machine | out-string | write-host
    ('************* RequestStatusInfo') | write-host
    $RequestStatusInfo | out-string | write-host
    ('************* RequestNetworkInfo') | write-host
    $RequestNetworkInfo | out-string | write-host
    ('************* DeployNetwork') | write-host
    $RequestNetworkInfo.DeployNetwork | out-string | write-host
    ('************* QueryParams') | write-host
    $QueryParams | out-string | write-host
    ('************* PostParams') | write-host
    $PostParams | out-string | write-host
    ('************* Paramdata') | write-host
    $paramData -replace '\r\n',"`r`n" | write-host
    ('*' * 80 ) | write-host

}


function Enable-HostOverride {
    
    remove-item alias:\write-verbose,alias:\write-Host,alias:\write-Warning,alias:\write-Error,alias:\write-Debug,alias:\write-Information -ErrorAction SilentlyContinue -Force | out-null

    new-alias write-verbose write-2PintInfo -Force -scope Script
    new-alias Write-Host write-2PintInfo -Force -scope Script
    new-alias Write-Information write-2PintInfo -Force -scope Script
    new-alias Write-Warning write-2PintWarning -Force -scope Script
    new-alias Write-Error write-2PintError -Force -scope Script
    new-alias Write-Debug write-2PintDebug -Force -scope Script

}

