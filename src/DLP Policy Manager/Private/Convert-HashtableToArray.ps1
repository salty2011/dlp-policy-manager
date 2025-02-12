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
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable[]]$HashtableList
    )

    begin {
        $customObjectArray = [System.Collections.ArrayList]::new()
    }

    process {
        try {
            foreach ($hashtable in $HashtableList) {
                Write-Debug "Processing hashtable: $($hashtable | ConvertTo-Json)"

                if ($null -eq $hashtable) {
                    Write-Debug "Skipping null hashtable"
                    continue
                }

                $properties = @{}
                foreach ($key in $hashtable.Keys) {
                    $properties[$key] = $hashtable[$key]
                }

                $newObject = [PSCustomObject]$properties
                Write-Debug "Created new object: $($newObject | ConvertTo-Json)"
                [void]$customObjectArray.Add($newObject)
                Write-Debug "Added object to array. Current count: $($customObjectArray.Count)"
            }
        } catch {
            Write-Error "Failed to convert hashtable to custom object array: $_"
            return
        }
    }

    end {
        Write-Debug "Returning array with count: $($customObjectArray.Count)"
        return ,[array]($customObjectArray.ToArray())
    }
}
