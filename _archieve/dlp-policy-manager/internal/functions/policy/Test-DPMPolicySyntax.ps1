function Test-DPMPolicySyntax {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$FilePaths
    )
    
    begin {
        $valid_modes = @("enable", "disable", "audit", "silent")
        $valid_split = @($true, $false)
        $validLocations = @("all", "onedrive", "sharepoint", "exchange", "teams")
        $results = @()

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
    }
    
    process {
        foreach ($filePath in $FilePaths) {
            try {
                $yamlContent = Get-Content -Path $filePath -Raw -ErrorAction Stop #BUG - Pointing at directory results in failure
                $yamlData = ConvertFrom-Yaml $yamlContent
            }
            catch {
                Write-Warning "Error reading or parsing file $filePath : $_"
                $results += [PSCustomObject]@{
                    FileName = (Split-Path $filePath -Leaf)
                    IsValid = $false
                    Errors = @("Failed to read or parse file")
                }
                continue
            }

            if (-not $yamlData.ContainsKey("policy")) {
                $results += [PSCustomObject]@{
                    FileName = (Split-Path $filePath -Leaf)
                    IsValid = $false
                    Errors = @("Missing 'policy' key")
                }
                continue
            }

            foreach ($policy in $yamlData.policy) {
                $policyResult = [PSCustomObject]@{
                    FileName = (Split-Path $filePath -Leaf)
                    PolicyName = $policy.name
                    IsValid = $true
                    Errors = @()
                    Locations = @()
                }

                # Check name
                if ([string]::IsNullOrWhiteSpace($policy.name)) {
                    $policyResult.IsValid = $false
                    $policyResult.Errors += "Name cannot be null or empty"
                }
                elseif ($policy.name -isnot [string]) {
                    $policyResult.IsValid = $false
                    $policyResult.Errors += "Name must be a string"
                }

                # Check mode
                if (-not $policy.ContainsKey("mode")) {
                    $policyResult.IsValid = $false
                    $policyResult.Errors += "Missing 'mode' key"
                }
                elseif ($policy.mode -notin $valid_modes) {
                    $policyResult.IsValid = $false
                    $policyResult.Errors += "Invalid mode: $($policy.mode). Valid modes are: $($valid_modes -join ', ')"
                }

                # Check split-by-type
                if (-not $policy.ContainsKey("split-by-type")) {
                    $policyResult.IsValid = $false
                    $policyResult.Errors += "Missing 'split-by-type' key"
                }
                elseif ($policy.'split-by-type' -isnot [bool]) {
                    $policyResult.IsValid = $false
                    $policyResult.Errors += "Invalid split-by-type value: $($policy.'split-by-type'). Must be true or false"
                }

                # Check include and locations
                if (-not $policy.ContainsKey("include")) {
                    $policyResult.IsValid = $false
                    $policyResult.Errors += "Missing 'include' key"
                }
                else {
                    $locationResult = Test-ValidLocations $policy.include
                    if (-not $locationResult.IsValid) {
                        $policyResult.IsValid = $false
                        $policyResult.Errors += "Invalid locations in 'include'"
                    }
                    foreach ($location in $locationResult.FoundLocations.Keys) {
                        if ($locationResult.FoundLocations[$location] -eq $true) {
                            $policyResult.Locations += $location
                        }
                        else {
                            $policyResult.Locations += "{0}:{1}" -f $location, $locationResult.FoundLocations[$location]
                        }
                    }
                }

                $results += $policyResult
            }
        }
    }
    
    end {
        return $results
    }
}