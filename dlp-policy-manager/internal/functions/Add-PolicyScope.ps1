function Add-PolicyScope {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Adds a key-value pair to a hashtable if the value is not null.

    .DESCRIPTION
    Adds a specified key and value to the provided hashtable only if the value is not null.

    .PARAMETER Value
    The value to be added. If null, the function does nothing.

    .PARAMETER Key
    The key under which the value should be stored.

    .PARAMETER Output
    The hashtable to which the key-value pair should be added.

    .EXAMPLE
    $hashTable = @{}
    Add-PolicyScope -Value "ExampleValue" -Key "ExampleKey" -Output $hashTable
    #>
    param (
        $Value,
        [string]$Key,
        [hashtable]$Output
    )
    Process {
        if ($Value) {
            $Output[$Key] = $Value
            Write-Verbose "Added $Key with value $Value to output"
        }
    }
}
