function Normalize-DLPaCKeys {
    <#
    .SYNOPSIS
        Normalizes keys in a PowerShell object to ensure consistent casing for schema validation.
    
    .DESCRIPTION
        The Normalize-DLPaCKeys function recursively processes PowerShell objects (hashtables, arrays, etc.)
        and normalizes the keys to ensure consistent casing. It maintains camelCase for specific properties
        that require it for schema validation.
    
    .PARAMETER InputObject
        The PowerShell object to normalize.
    
    .EXAMPLE
        $normalizedObject = Normalize-DLPaCKeys -InputObject $yamlObject
        
        Normalizes all keys in the YAML object while maintaining proper casing for schema validation.
    
    .NOTES
        This is an internal function used by multiple DLPaC cmdlets for schema validation.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [object]$InputObject
    )
    
    # Handle null values
    if ($null -eq $InputObject) {
        return $null
    }
    
    # Define a mapping of lowercase keys to their correct camelCase versions
    $camelCaseMap = @{
        "notifyuser" = "notifyUser"
        "notifyadmin" = "notifyAdmin"
        "mincount" = "minCount"
        "encryptionmethod" = "encryptionMethod"
        "infotype" = "infoType"
    }
    
    # Handle hashtables and ordered dictionaries
    if ($InputObject -is [hashtable] -or $InputObject -is [System.Collections.Specialized.OrderedDictionary]) {
        $normalizedObject = @{}
        
        foreach ($key in $InputObject.Keys) {
            # First convert key to lowercase for comparison
            $lowerKey = $key.ToLower()
            $value = $InputObject[$key]
            
            # Use the camelCase version if it exists in our map, otherwise use lowercase
            $normalizedKey = if ($camelCaseMap.ContainsKey($lowerKey)) {
                $camelCaseMap[$lowerKey]
            } else {
                $lowerKey
            }
            
            # Recursively normalize nested objects
            $normalizedValue = Normalize-DLPaCKeys -InputObject $value
            $normalizedObject[$normalizedKey] = $normalizedValue
        }
        
        # Ensure all expected scope keys are present as arrays
        if ($normalizedObject.ContainsKey("scope")) {
            $expectedScopes = @("exchange","sharepoint","onedrive","teams","devices")
            foreach ($scopeKey in $expectedScopes) {
                if (-not $normalizedObject["scope"].ContainsKey($scopeKey)) {
                    $normalizedObject["scope"][$scopeKey] = @()
                } elseif ($null -eq $normalizedObject["scope"][$scopeKey]) {
                    Write-Warning "Scope '$scopeKey' is set to null and will be ignored. Use an empty array '[]' to explicitly disable."
                    $normalizedObject["scope"][$scopeKey] = @()
                } else {
                    # Convert scope values to array if they aren't already
                    $currentValue = $normalizedObject["scope"][$scopeKey]
                    if ($currentValue -isnot [array]) {
                        $normalizedObject["scope"][$scopeKey] = @($currentValue)
                    }
                }
            }
        }
        return $normalizedObject
    }
    # Handle arrays and collections - ensure they remain arrays
    elseif ($InputObject -is [array] -or 
           ($InputObject.GetType().IsGenericType -and 
            $InputObject.GetType().GetGenericTypeDefinition() -eq [System.Collections.Generic.List`1]) -or
           ($InputObject -is [System.Collections.IList] -and -not ($InputObject -is [string]))) {
        
        # Create a proper array to ensure type consistency
        $normalizedArray = [System.Collections.ArrayList]::new()
        
        foreach ($item in $InputObject) {
            $normalizedItem = Normalize-DLPaCKeys -InputObject $item
            $normalizedArray.Add($normalizedItem) | Out-Null
        }
        
        # Convert back to a standard PowerShell array
        return @($normalizedArray)
    }
    # Handle all other types (strings, numbers, booleans, etc.)
    else {
        return $InputObject
    }
}