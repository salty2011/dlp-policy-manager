function Build-DPMPolicy {
<#
.SYNOPSIS
    Builds DLP policies from YAML files within a specified directory.

.DESCRIPTION
    This function reads YAML files containing policy definitions, processes them according to specified criteria,
    and returns the compiled list of policy objects.

.PARAMETER Path
    Specifies the directory path where the YAML policy files are located.

.EXAMPLE
    $policies = Build-DPMPolicy -Path "C:\Policies"

.NOTES
    Ensure that each YAML file is properly formatted according to the expected schema for DLP policies.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$Path
    )
    
    begin {
        [System.Collections.Generic.List[object]]$result = @()
        $fileFilter = "*.yml"
        $files = Get-ChildItem -Path $Path -Filter $fileFilter
    }
    
    process {
        foreach ($file in $files) {
            try {
                $ymlData = Get-Content $file.FullName | ConvertFrom-Yaml
                foreach ($yml in $ymlData.policy) {
                    $output = @{
                        Name    = $yml.name
                        Comment = $yml.description
                        Mode    = $dpm_policy_config.Mode[$yml.mode]
                    }

                    if ($yml["split-by-type"]) {
                        $yml.include.Keys | ForEach-Object {
                            if ($yml.include[$_]) {
                                $policy = $output.Clone()
                                $policy.Name += "-$_"
                                Add-Scopes -scopes $dpm_policy_config.Scopes[$_] -output $policy -yml $yml.include[$_]
                                $result.Add($policy)
                            }
                        }
                    }
                    else {
                        $yml.include.Keys | ForEach-Object {
                            if ($yml.include[$_]) {
                                Add-Scopes -scopes $dpm_policy_config.Scopes[$_] -output $output -yml $yml.include[$_]
                            }
                        }
                        $result.Add($output)
                    }
                }
            } catch {
                Write-Error "Failed to process file '$($file.FullName)': $_"
            }
        } 
    }
    
    end {
        return $result
    }
}