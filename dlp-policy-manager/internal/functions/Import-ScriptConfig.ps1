# XXX - Note sure if this is still needed
#Think this can be removed as now built into module
function Import-ScriptConfig {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Imports configuration settings from a PSD1 file.

    .DESCRIPTION
    This function loads configuration settings from a specified PSD1 file located in the script's root directory.

    .PARAMETER FileName
    The filename of the configuration PSD1 file to import.

    .EXAMPLE
    $config = Import-ScriptConfig -FileName "build_policy.config.psd1"
    #>
    param (
        [string]$FileName
    )
    Begin {
        Write-Verbose "Importing configuration from $FileName"
    }
    Process {
        Import-LocalizedData -BaseDirectory $PSScriptRoot -FileName $FileName
    }
    End {
        Write-Verbose "Configuration import completed"
    }
}
