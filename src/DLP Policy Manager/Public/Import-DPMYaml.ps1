<#
.SYNOPSIS
    Imports DLP (Data Loss Prevention) configurations from YAML files.

.DESCRIPTION
    The Import-DPMYaml function reads YAML files from a specified directory and imports DLP configurations
    including policies, rules, and labels. It supports both .yml and .yaml file extensions and allows
    selective import of specific configuration types.

.PARAMETER Path
    The directory path containing the YAML configuration files to import.
    The path must exist and be a valid directory.

.PARAMETER ImportType
    Specifies which types of configurations to import. Valid values are:
    - 'All': Imports all configuration types (default)
    - 'Policies': Imports only DLP policies
    - 'Rules': Imports only DLP rules
    - 'Labels': Imports only DLP labels
    Multiple values can be specified.

.EXAMPLE
    Import-DPMYaml -Path "C:\DLPConfigs"
    Imports all DLP configurations from YAML files in the specified directory.

.EXAMPLE
    Import-DPMYaml -Path "C:\DLPConfigs" -ImportType Policies
    Imports only DLP policies from YAML files in the specified directory.

.EXAMPLE
    Import-DPMYaml -Path "C:\DLPConfigs" -ImportType Policies, Rules
    Imports both DLP policies and rules from YAML files in the specified directory.

.OUTPUTS
    Returns a hashtable containing arrays of imported items:
    - Policies: Array of imported DLP policies
    - Rules: Array of imported DLP rules
    - Labels: Array of imported DLP labels

.NOTES
    File Name      : Import-DPMYaml.ps1
    Prerequisite   : PowerShell 5.1 or later
    Required Modules: powershell-yaml

.LINK
    https://github.com/yourgithubrepo/DLPPolicyManager
#>

function Import-DPMYaml {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript({
            if (-not (Test-Path $_ -PathType Container)) {
                throw "Path '$_' does not exist or is not a directory."
            }
            return $true
        })]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [ValidateSet('All', 'Policies', 'Rules', 'Labels')]
        [string]$ImportType = 'All'
    )

    begin {
        # Include both .yml and .yaml extensions
        $fileFilters = @("*.yml", "*.yaml")
        $importedItems = @{
            Policies = @()
            Rules = @()
            Labels = @()
        }
    }

    process {
        foreach ($filter in $fileFilters) {
            $files = Get-ChildItem -Path $Path -Filter $filter

            foreach ($file in $files) {
                try {
                    Write-Verbose "Processing file: $($file.FullName)"

                    $ymlContent = Get-Content -Path $file.FullName -Raw
                    if ([string]::IsNullOrWhiteSpace($ymlContent)) {
                        Write-Warning "File '$($file.Name)' is empty"
                        continue
                    }

                    $yml = $ymlContent | ConvertFrom-Yaml

                    # Convert comma-separated ImportType to array if needed
                    $importTypes = $ImportType.Split(',').Trim()

                    # Import Policies if specified
                    if ($importTypes -contains 'All' -or $importTypes -contains 'Policies') {
                        if ($yml.policies) {
                            foreach ($policy in $yml.policies) {
                                $newPolicy = New-DPMDLPPolicy -PolicyData $policy
                                $importedItems.Policies += $newPolicy
                                Write-Verbose "Imported policy from $($file.Name)"
                            }
                        }
                    }

                    # Import Rules if specified
                    if ($importTypes -contains 'All' -or $importTypes -contains 'Rules') {
                        if ($yml.Rules) {
                            foreach ($rule in $yml.Rules) {
                                # Placeholder for future Rule import functionality
                                # $newRule = New-DPMDLPRule -RuleData $rule
                                # $importedItems.Rules += $newRule
                                Write-Verbose "Rule import not yet implemented"
                            }
                        }
                    }

                    # Import Labels if specified
                    if ($importTypes -contains 'All' -or $importTypes -contains 'Labels') {
                        if ($yml.Labels) {
                            foreach ($label in $yml.Labels) {
                                # Placeholder for future Label import functionality
                                # $newLabel = New-DPMDLPLabel -LabelData $label
                                # $importedItems.Labels += $newLabel
                                Write-Verbose "Label import not yet implemented"
                            }
                        }
                    }
                }
                catch {
                    Write-Error "Failed to process file '$($file.Name)': $_"
                }
            }
        }
    }

    end {
        # Return all imported items
        return $importedItems
    }
}