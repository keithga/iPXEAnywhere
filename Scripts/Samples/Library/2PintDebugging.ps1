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

    ('************* Machine') | Write-2PintLog
    $Machine | out-string | Write-2PintLog
    ('************* RequestStatusInfo') | Write-2PintLog
    $RequestStatusInfo | out-string | Write-2PintLog
    ('************* RequestNetworkInfo') | Write-2PintLog
    $RequestNetworkInfo | out-string | Write-2PintLog
    ('************* DeployNetwork') | Write-2PintLog
    $RequestNetworkInfo.DeployNetwork | out-string | Write-2PintLog
    ('************* QueryParams') | Write-2PintLog
    $QueryParams | out-string | Write-2PintLog
    ('************* PostParams') | Write-2PintLog
    $PostParams | out-string | Write-2PintLog
    ('************* Paramdata') | Write-2PintLog
    $paramData -replace '\r\n',"`r`n" | Write-2PintLog
    ('*' * 80 ) | Write-2PintLog

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

