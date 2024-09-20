function Convert-HashtableToArray {
    <#
    .SYNOPSIS
        Converts a list of hashtables to an array of custom objects.

    .DESCRIPTION
        This function takes a list of hashtables and converts each hashtable into a custom object,
        then collects all these objects into an array. This is useful for normalizing data structures
        for comparison or processing.

    .PARAMETER HashtableList
        A list of hashtables where each hashtable contains a set of key-value pairs.

    .EXAMPLE
        $hashtableList = @(
            @{Name = 'Rule1'; Policy = 'Policy1'; BlockAccess = $true},
            @{Name = 'Rule2'; Policy = 'Policy2'; BlockAccess = $false}
        )
        $objectArray = Convert-HashtableToArray -HashtableList $hashtableList
        $objectArray | Format-Table -AutoSize

    .NOTES
        Author: [Your Name]
        Created: [Creation Date]
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[hashtable]]$HashtableList
    )
    
    $customObjectArray = @()
    
    try {
        foreach ($hashtable in $HashtableList) {
            $customObject = New-Object -TypeName PSObject
            foreach ($key in $hashtable.Keys) {
                $customObject | Add-Member -MemberType NoteProperty -Name $key -Value $hashtable[$key]
            }
            $customObjectArray += $customObject
        }
    } catch {
        Write-Error "Failed to convert hashtable to custom object array: $_"
        return $null
    }
    
    return $customObjectArray
}
