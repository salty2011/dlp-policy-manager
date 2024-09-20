function Compare-DPMConfigurations {
    <#
    .SYNOPSIS
        Compares DLP policies from the current tenant configuration with those defined in YAML files.

    .DESCRIPTION
        This function compares the DLP policies currently configured in the tenant with those defined in YAML files.
        It provides a detailed comparison of policies, including added, removed, and modified policies and their rules.

    .PARAMETER Path
        Specifies the directory path where the YAML policy files are located.

    .EXAMPLE
        $comparison = Compare-DPMConfigurations -Path "C:\Policies"

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
        AddedPolicies = @()
        RemovedPolicies = @()
        ModifiedPolicies = @()
    }

    # Check for added and modified policies
    foreach ($definedPolicy in $definedPolicies) {
        $currentPolicy = $currentPolicies | Where-Object { $_.Name -eq $definedPolicy.Name }
        if (-not $currentPolicy) {
            $comparison.AddedPolicies += $definedPolicy
        } else {
            $differences = Compare-PolicyObjects -DefinedPolicy $definedPolicy -CurrentPolicy $currentPolicy
            if ($differences) {
                $comparison.ModifiedPolicies += @{
                    PolicyName = $definedPolicy.Name
                    Differences = $differences
                }
            }
        }
    }

    # Check for removed policies
    foreach ($currentPolicy in $currentPolicies) {
        if (-not ($definedPolicies | Where-Object { $_.Name -eq $currentPolicy.Name })) {
            $comparison.RemovedPolicies += $currentPolicy
        }
    }

    return $comparison
}

function Compare-PolicyObjects {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$DefinedPolicy,
        
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$CurrentPolicy
    )

    $differences = @{}

    # Compare policy properties
    $propertiesToCompare = @('Mode', 'Comment', 'ExchangeLocation', 'SharePointLocation', 'OneDriveLocation', 'TeamsLocation', 'SplitByType')
    $arrayProperties = @('ExchangeLocation', 'SharePointLocation', 'OneDriveLocation', 'TeamsLocation')
    foreach ($prop in $propertiesToCompare) {
        if ($prop -in $arrayProperties) {
            $definedValue = $DefinedPolicy.$prop
            $currentValue = $CurrentPolicy.$prop
            if ($definedValue -ne $currentValue) {
                $differences[$prop] = @{
                    Defined = $definedValue
                    Current = $currentValue
                }
            }
        } elseif ($DefinedPolicy.$prop -ne $CurrentPolicy.$prop) {
            $differences[$prop] = @{
                Defined = $DefinedPolicy.$prop
                Current = $CurrentPolicy.$prop
            }
        }
    }

    return $differences
}

function Compare-Rules {
    param (
        [Parameter(Mandatory = $true)]
        [Array]$DefinedRules,
        
        [Parameter(Mandatory = $true)]
        [Array]$CurrentRules
    )

    $ruleDifferences = @{
        AddedRules = @()
        RemovedRules = @()
        ModifiedRules = @()
    }

    foreach ($definedRule in $DefinedRules) {
        $currentRule = $CurrentRules | Where-Object { $_.Name -eq $definedRule.Name }
        if (-not $currentRule) {
            $ruleDifferences.AddedRules += $definedRule
        } else {
            $differences = Compare-RuleObjects -DefinedRule $definedRule -CurrentRule $currentRule
            if ($differences) {
                $ruleDifferences.ModifiedRules += @{
                    RuleName = $definedRule.Name
                    Differences = $differences
                }
            }
        }
    }

    foreach ($currentRule in $CurrentRules) {
        if (-not ($DefinedRules | Where-Object { $_.Name -eq $currentRule.Name })) {
            $ruleDifferences.RemovedRules += $currentRule
        }
    }

    return $ruleDifferences
}

function Compare-RuleObjects {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$DefinedRule,
        
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$CurrentRule
    )

    $differences = @{}

    # Compare rule properties
    $propertiesToCompare = @('Disabled', 'ContentContainsSensitiveInformation', 'AccessScope', 'BlockAccess', 'BlockAccessScope', 'NotifyUser', 'NotifyUserType', 'NotifyUserText')
    foreach ($prop in $propertiesToCompare) {
        if ($prop -eq 'ContentContainsSensitiveInformation') {
            $definedSCI = $DefinedRule.$prop | ConvertTo-Json -Depth 5
            $currentSCI = $CurrentRule.$prop | ConvertTo-Json -Depth 5
            if ($definedSCI -ne $currentSCI) {
                $differences[$prop] = @{
                    Defined = $DefinedRule.$prop
                    Current = $CurrentRule.$prop
                }
            }
        } elseif ($DefinedRule.$prop -ne $CurrentRule.$prop) {
            $differences[$prop] = @{
                Defined = $DefinedRule.$prop
                Current = $CurrentRule.$prop
            }
        }
    }

    return $differences
}
