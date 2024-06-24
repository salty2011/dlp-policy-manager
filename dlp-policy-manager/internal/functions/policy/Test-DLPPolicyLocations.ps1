# BUG: OverallValid returns null when all policies are valid
function Test-DLPPolicyLocations {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$FilePaths,
        [switch]$ReturnFullObject
    )

    # Define valid locations
    $validLocations = @("all", "onedrive", "sharepoint", "exchange", "teams")

    # Function to check if locations are valid and return found locations
    function Test-ValidLocations($includeData) {
        $isValid = $true
        $foundLocations = @{}

        foreach ($key in $includeData.Keys) {
            if ($key -in $validLocations) {
                $foundLocations[$key] = $true
                if ($includeData[$key] -is [Hashtable]) {
                    foreach ($subKey in $includeData[$key].Keys) {
                        if ($subKey -eq "location") {
                            $locationValue = $includeData[$key][$subKey]
                            if ($locationValue -in $validLocations) {
                                $foundLocations["$key.location"] = $locationValue
                            }
                            else {
                                Write-Verbose "Invalid location found: $locationValue in $key"
                                $isValid = $false
                            }
                        }
                    }
                }
            }
            else {
                Write-Verbose "Invalid key found: $key"
                $isValid = $false
            }
        }

        return @{
            IsValid = $isValid
            FoundLocations = $foundLocations
        }
    }

    $overallValid = $true
    $policyResults = @()

    foreach ($filePath in $FilePaths) {
        try {
            $yamlContent = Get-Content -Path $filePath -Raw -ErrorAction Stop
            $yamlData = ConvertFrom-Yaml $yamlContent
        }
        catch {
            Write-Warning "Error reading or parsing file $filePath : $_"
            $overallValid = $false
            continue
        }

        if (-not $yamlData.ContainsKey("policy")) {
            Write-Warning "The YAML file $filePath does not contain a 'policy' key."
            $overallValid = $false
            continue
        }

        foreach ($policy in $yamlData.policy) {
            $policyResult = [PSCustomObject]@{
                FileName = (Split-Path $filePath -Leaf)
                PolicyName = $policy.name
                IsValid = $true
                Locations = @()
            }

            if ($policy.ContainsKey("include")) {
                $result = Test-ValidLocations $policy.include
                $policyResult.IsValid = $result.IsValid
                
                foreach ($location in $result.FoundLocations.Keys) {
                    if ($result.FoundLocations[$location] -eq $true) {
                        $policyResult.Locations += $location
                    }
                    else {
                        $policyResult.Locations += "{0}:{1}" -f $location, $result.FoundLocations[$location]
                    }
                }
            }
            else {
                Write-Verbose "Policy $($policy.name) in file $filePath does not have an 'include' section."
                $policyResult.IsValid = $false
            }

            $overallValid = $overallValid -and $policyResult.IsValid
            $policyResults += $policyResult
        }
    }

    $formattedResults = $policyResults | ForEach-Object {
        [PSCustomObject]@{
            FileName = $_.FileName
            PolicyName = $_.PolicyName
            IsValid = $_.IsValid
            Locations = $_.Locations -join ', '
        }
    }

    if ($ReturnFullObject) {
        $result = [PSCustomObject]@{
            OverallValid = $overallValid
            PoliciesTested = $formattedResults
            ToString = { 
                $output = "Overall Valid: $($this.OverallValid)`n`n"
                $output += $this.PoliciesTested | ForEach-Object {
                    "File: $($_.FileName)`n" +
                    "Policy: $($_.PolicyName)`n" +
                    "Is Valid: $($_.IsValid)`n" +
                    "Locations: $($_.Locations)`n`n"
                }
                return $output
            }
        }
        $result.PSObject.TypeNames.Insert(0, 'DLPPolicyLocationResult')
        return $result
    } else {
        return $formattedResults
    }
}