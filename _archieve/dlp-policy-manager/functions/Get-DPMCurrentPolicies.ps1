function Get-DPMCurrentPolicies {
    <#
    .SYNOPSIS
        Retrieves currently configured DLP compliance policies.

    .DESCRIPTION
        This function fetches the currently active DLP policies using the Get-DLPCompliancePolicy cmdlet and returns a structured list of these policies.

    .EXAMPLE
        $currentPolicies = Get-DPMCurrentPolicies
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
                    Mode = $policy.Mode
                    Comment = $policy.Comment
                    Priority = $policy.Priority
                    ExchangeLocation = $policy.ExchangeLocation
                    ExchangeSenderMemberOf = $policy.ExchangeSenderMemberOf
                    ExchangeSenderMemberOfException = $policy.ExchangeSenderMemberOfException
                    SharePointLocation = $policy.SharePointLocation
                    OneDriveLocation = $policy.OneDriveLocation
                    TeamsLocation = $policy.TeamsLocation
                    EndpointDlpLocation = $policy.EndpointDlpLocation
                    Enabled = $policy.Enabled
                    Rules = @()
                }

                # Fetch and add rules for each policy
                $rules = Get-DlpComplianceRule -Policy $policy.Name
                foreach ($rule in $rules) {
                    $ruleObject = [PSCustomObject]@{
                        Name = $rule.Name
                        Disabled = $rule.Disabled
                        ContentContainsSensitiveInformation = $rule.ContentContainsSensitiveInformation
                        # Add other relevant rule properties here
                    }
                    $policyObject.Rules += $ruleObject
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

function Compare-DPMPolicies {
    <#
    .SYNOPSIS
        Compares current DLP policies with those defined in YAML files.

    .DESCRIPTION
        This function compares the DLP policies currently configured in the tenant
        with those defined in YAML files. It helps identify discrepancies between
        what's defined locally and what's actually deployed.

    .PARAMETER Path
        The path to the directory containing the YAML policy files.

    .EXAMPLE
        Compare-DPMPolicies -Path "C:\Policies"

    .NOTES
        Ensure you have the necessary permissions to read the YAML files and retrieve current DLP policies.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$Path
    )

    # Get current policies from the tenant
    $currentPolicies = Get-DPMCurrentPolicies

    # Build policies from YAML files
    $definedPolicies = Build-DPMPolicy -Path $Path

    # Compare policies
    $comparison = @{
        OnlyInTenant = @()
        OnlyInYAML = @()
        Matching = @()
        Differing = @()
    }

    foreach ($current in $currentPolicies) {
        $defined = $definedPolicies | Where-Object { $_.Name -eq $current.Name }
        if ($defined) {
            if ($defined.Mode -eq $current.Mode) {
                $comparison.Matching += $current.Name
            } else {
                $comparison.Differing += @{
                    Name = $current.Name
                    TenantMode = $current.Mode
                    YAMLMode = $defined.Mode
                }
            }
        } else {
            $comparison.OnlyInTenant += $current.Name
        }
    }

    foreach ($defined in $definedPolicies) {
        if (-not ($currentPolicies | Where-Object { $_.Name -eq $defined.Name })) {
            $comparison.OnlyInYAML += $defined.Name
        }
    }

    return $comparison
}
