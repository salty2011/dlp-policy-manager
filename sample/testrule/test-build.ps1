. C:\code\dlp-policy-manager\dlp-policy-manager\internal\functions\Get-ContentConditions.ps1
. C:\code\dlp-policy-manager\dlp-policy-manager\internal\functions\Get-DLPCondition.ps1
$rules = @()
$template = [string](Get-Content "C:\code\dlp-policy-manager\dlp-policy-manager\internal\templates\rule.template")
$dpm_rule_config = Import-LocalizedData -BaseDirectory "C:\code\dlp-policy-manager\dlp-policy-manager\internal\" -FileName "rule.config.psd1"

$path = '.\'
$fileFilter = "*.yml"
$files = Get-ChildItem -Path $Path -Filter $fileFilter
[System.Collections.Generic.List[object]]$result = @()

foreach ($file in $files) {
    Write-Verbose "Processing file: $($file.FullName)"

        $ymlData = Get-Content $file.FullName | ConvertFrom-Yaml -ErrorAction Stop

        # Ensure there is a 'rule' key in the YAML data
        if (-not $ymlData.rule) {
            Write-Warning "No 'rule' key found in file: $($file.FullName)"
            continue
        }

        # Iterate over each rule defined under the 'rule' key
        foreach ($rule in $ymlData.rule) {
            $binding = @{
                Operator      = $rule.conditions.operator
                SubConditions = @()
            }

            # Process conditions if they exist
            if ($rule.conditions) {
                $rule.conditions.Keys | ForEach-Object {
                    switch ($_) {
                        "content" {
                            $binding.SubConditions += Get-ContentConditions -ContentConditionRules $rule.conditions[$_]
                        }
                        "email" {
                            $binding.SubConditions += Get-EmailConditions -EmailRules $rule.conditions[$_]
                        }
                        Default {
                            if ($dpm_rule_config.SubConditions.ContainsKey($_)) {
                                $binding.SubConditions += Get-DLPCondition -Value $rule.conditions[$_] -Key $dpm_rule_config.SubConditions[$_]
                            }
                        }
                    }
                }
            }

            # Invoke the rule template processing
            $processedRule = Invoke-EPSTemplate -Template $template -Binding $binding
            $output = @{
                Name = $rule.name
                AdvancedRule = $processedRule
                Policy = $rule.policy
                BlockAccess = $true
            }
            $result.Add($output)
            Write-Output "Successfully added rule: $($output.Name)"
        }

        Write-Output "Failed to process file '$($file.FullName)': $_"

}

return $result

function Build-DPMRule {
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
                $ymlData = Get-Content $file.FullName | ConvertFrom-Yaml -ErrorAction Stop

                # Ensure there is a 'rule' key in the YAML data
                if (-not $ymlData.rule) {
                    Write-Warning "No 'rule' key found in file: $($file.FullName)"
                    continue
                }

                # Iterate over each rule defined under the 'rule' key
                foreach ($rule in $ymlData.rule) {
                    $binding = @{
                        Operator      = $rule.conditions.operator
                        SubConditions = @()
                    }

                    # Process conditions if they exist
                    if ($rule.conditions) {
                        $rule.conditions.Keys | ForEach-Object {
                            switch ($_) {
                                "content" {
                                    $binding.SubConditions += Get-ContentConditions -ContentConditionRules $rule.conditions[$_]
                                }
                                "email" {
                                    $binding.SubConditions += Get-EmailConditions -EmailRules $rule.conditions[$_]
                                }
                                Default {
                                    if ($dpm_rule_config.SubConditions.ContainsKey($_)) {
                                        $binding.SubConditions += Get-DLPCondition -Value $rule.conditions[$_] -Key $dpm_rule_config.SubConditions[$_]
                                    }
                                }
                            }
                        }
                    }

                    # Invoke the rule template processing
                    $processedRule = Invoke-EPSTemplate -Template $template -Binding $binding
                    $output = @{
                        Name = $rule.name
                        AdvancedRule = $processedRule
                        Policy = $rule.policy
                        BlockAccess = $true
                    }
                    $result.Add($output)
                    Write-Verbose "Successfully added rule: $($output.Name)"
                }
            } catch {
                Write-Warning "Failed to process file '$($file.FullName)': $_"
            }
        } 
    }
    
    end {
        Write-Verbose "Completed processing all files. Returning results."
        return $result
    }
}