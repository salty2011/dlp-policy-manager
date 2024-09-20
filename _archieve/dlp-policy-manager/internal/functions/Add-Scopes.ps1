function Add-Scopes {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Adds multiple scopes to the output based on the provided configuration.

    .DESCRIPTION
    Iterates through each scope key in the provided scopes hashtable and, if present in the YAML data, adds them to the output hashtable.

    .PARAMETER Scopes
    A hashtable of scope keys and their corresponding output keys.

    .PARAMETER Yml
    The YAML data from which to extract values.

    .PARAMETER Output
    The output hashtable where scopes are added.

    .EXAMPLE
    $scopes = @{ "Key1" = "OutputKey1"; "Key2" = "OutputKey2" }
    $yamlData = @{ "Key1" = "Value1"; "Key2" = "Value2" }
    $outputHash = @{}
    Add-Scopes -Scopes $scopes -Yml $yamlData -Output $outputHash
    #>
    param (
        [hashtable]$Scopes,
        [hashtable]$Yml,
        [hashtable]$Output
    )
    Begin {
        Write-Verbose "Starting to add scopes..."
    }
    Process {
        $Scopes.Keys | ForEach-Object {
            if ($null -ne $Yml[$_]) {
                Add-PolicyScope -Output $Output -Key $Scopes[$_] -Value $Yml[$_]
                Write-Verbose "Processing scope for key $_"
            }
        }
    }
    End {
        Write-Verbose "All scopes have been added."
    }
}
