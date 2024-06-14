function Build-DPMRule {
    <#
    .SYNOPSIS
        Builds DLP rules from YAML files within a specified directory.
    
    .DESCRIPTION
        This function reads YAML files containing rule definitions, processes them according to specified criteria,
        and returns the compiled list of rule objects.
    
    .PARAMETER Path
        Specifies the directory path where the YAML rule files are located.
    
    .EXAMPLE
        $rules = Build-DPMRule -Path "C:\Rules"
    
    .NOTES
        Ensure that each YAML file is properly formatted according to the expected schema for DLP rules.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$Path
    )
        
    begin {
        Write-Verbose "Initializing variables and fetching files from: $Path"
        $fileFilter = "*.yml"
        $files = Get-ChildItem -Path $Path -Filter $fileFilter
        [System.Collections.Generic.List[object]]$result = @()
    }
        
    process {
        foreach ($file in $files) {
            Write-Verbose "Processing file: $($file.FullName)"
            try {
                $yml = Get-Content $file.FullName | ConvertFrom-Yaml -ErrorAction Stop
    
                $binding = @{
                    Operator      = $yml.conditions.operator
                    SubConditions = @()
                }
                    
                $yml.conditions.Keys | ForEach-Object {
                    if ($yml.conditions[$_]) {
                        switch ($_) {
                            "content" { 
                                $binding.SubConditions += Get-ContentConditions -ContentConditionRules $yml.conditions[$_] -ErrorAction Stop
                            }
                            "email" {
                                $binding.SubConditions += Get-EmailConditions -EmailRules $yml.conditions[$_] -ErrorAction Stop
                            }
                            "operator" {
                                # Ignore
                            }
                            Default {
                                $binding.SubConditions += Get-DLPCondition -Value $yml.conditions[$_] -Key $dpm_rule_config.SubConditions[$_] -ErrorAction Stop
                            }
                        }
                    }
                }
                    
                $rule = Invoke-EPSTemplate -Template $template -Binding $binding -ErrorAction Stop
                $output = @{Name = $yml.name; AdvancedRule = $rule; Policy = $yml.policy; BlockAccess = $true }
                $result.Add($output)
                Write-Verbose "Successfully added rule: $($output.Name)"
            }
            catch {
                Write-Warning "Failed to process file '$($file.FullName)': $_"
            }
        }
    }
        
    end {
        Write-Verbose "Completed processing all files. Returning results."
        return $result
    }
}