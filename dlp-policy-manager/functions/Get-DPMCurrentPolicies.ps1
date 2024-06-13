function Get-DPMCurrentPolicies {
    <#
.SYNOPSIS
    Retrieves currently configured DLP compliance policies.

.DESCRIPTION
    This function fetches the currently active DLP policies using the Get-DLPCompliancePolicy cmdlet and returns a structured list of these policies.

.EXAMPLE
    $currentPolicies = Get-CurrentDLPCompliancePolicies
    This example retrieves all currently configured DLP compliance policies and stores them in a variable.

.NOTES
    Ensure you are authenticated and have the necessary permissions to execute Get-DLPCompliancePolicy.
#>

    [CmdletBinding()]
    param ()
    
    begin {
        [System.Collections.Generic.List[object]]$result = @()
    }
    
    process {
        try {
            # Retrieve all DLP compliance policies
            $policies = Get-DLPCompliancePolicy
            foreach ($policy in $policies) {
                # Create a custom object for each policy to ensure consistency in output structure
                $policyObject = [PSCustomObject]@{
                    Name = $policy.Name
                    Mode = $policy.Mode  # Assuming 'Mode' is a property; adjust as necessary
                    Comment = "Retrieved from live configuration"
                }
                $result.Add($policyObject)
            }
        } catch {
            Write-Error "Failed to retrieve DLP compliance policies: $_"
        }
    }
    
    end {
        return $result
    }
}
