# Test script for YAML validation
param(
    [Parameter(Mandatory=$true)]
    [string]$YamlFilePath
)

# Import the powershell-yaml module
Import-Module powershell-yaml

# Read the YAML file
$yamlContent = Get-Content -Path $YamlFilePath -Raw
Write-Host "YAML content read successfully"

# Try to parse the YAML
try {
    $yamlObject = $yamlContent | ConvertFrom-Yaml
    Write-Host "YAML parsed successfully"
    
    # Check if the parsed object has the expected structure
    if ($yamlObject -is [hashtable] -and $yamlObject.ContainsKey('policies')) {
        Write-Host "YAML has the expected top-level 'policies' key"
        
        # Check if policies is an array
        if ($yamlObject.policies -is [array]) {
            Write-Host "Policies is an array with $($yamlObject.policies.Count) items"
            
            # Check each policy
            foreach ($policy in $yamlObject.policies) {
                Write-Host "Checking policy: $($policy.name)"
                
                # Check required fields
                $requiredFields = @('name', 'mode', 'rules')
                $missingFields = $requiredFields | Where-Object { -not $policy.ContainsKey($_) }
                
                if ($missingFields.Count -eq 0) {
                    Write-Host "  Policy has all required fields"
                } else {
                    Write-Host "  Policy is missing required fields: $($missingFields -join ', ')" -ForegroundColor Red
                }
                
                # Check rules
                if ($policy.ContainsKey('rules') -and $policy.rules -is [array]) {
                    Write-Host "  Policy has $($policy.rules.Count) rules"
                    
                    # Check each rule
                    foreach ($rule in $policy.rules) {
                        Write-Host "  Checking rule: $($rule.name)"
                        
                        # Check required fields
                        $ruleRequiredFields = @('name', 'conditions', 'actions')
                        $ruleMissingFields = $ruleRequiredFields | Where-Object { -not $rule.ContainsKey($_) }
                        
                        if ($ruleMissingFields.Count -eq 0) {
                            Write-Host "    Rule has all required fields"
                        } else {
                            Write-Host "    Rule is missing required fields: $($ruleMissingFields -join ', ')" -ForegroundColor Red
                        }
                        
                        # Check conditions
                        if ($rule.ContainsKey('conditions') -and $rule.conditions -is [array]) {
                            Write-Host "    Rule has $($rule.conditions.Count) conditions"
                            
                            # Check each condition
                            foreach ($condition in $rule.conditions) {
                                Write-Host "    Checking condition type: $($condition.type)"
                                
                                # Check required fields based on type
                                if ($condition.type -eq "ContentContainsPattern" -and -not $condition.ContainsKey('pattern')) {
                                    Write-Host "      ContentContainsPattern condition is missing 'pattern'" -ForegroundColor Red
                                }
                                elseif ($condition.type -eq "SensitiveInfoType" -and -not $condition.ContainsKey('infoType')) {
                                    Write-Host "      SensitiveInfoType condition is missing 'infoType'" -ForegroundColor Red
                                }
                                elseif ($condition.type -eq "RecipientDomain" -and (-not $condition.ContainsKey('operator') -or -not $condition.ContainsKey('value'))) {
                                    Write-Host "      RecipientDomain condition is missing 'operator' or 'value'" -ForegroundColor Red
                                }
                                elseif ($condition.type -eq "AccessScope" -and -not $condition.ContainsKey('value')) {
                                    Write-Host "      AccessScope condition is missing 'value'" -ForegroundColor Red
                                }
                                else {
                                    Write-Host "      Condition has all required fields for its type"
                                }
                            }
                        } else {
                            Write-Host "    Rule is missing conditions array or it's not an array" -ForegroundColor Red
                        }
                        
                        # Check actions
                        if ($rule.ContainsKey('actions') -and $rule.actions -is [array]) {
                            Write-Host "    Rule has $($rule.actions.Count) actions"
                            
                            # Check each action
                            foreach ($action in $rule.actions) {
                                Write-Host "    Checking action type: $($action.type)"
                                
                                # Check required fields based on type
                                if ($action.type -eq "Encrypt" -and -not $action.ContainsKey('encryptionMethod')) {
                                    Write-Host "      Encrypt action is missing 'encryptionMethod'" -ForegroundColor Red
                                }
                                else {
                                    Write-Host "      Action has all required fields for its type"
                                }
                            }
                        } else {
                            Write-Host "    Rule is missing actions array or it's not an array" -ForegroundColor Red
                        }
                    }
                } else {
                    Write-Host "  Policy is missing rules array or it's not an array" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "Policies is not an array" -ForegroundColor Red
        }
    } else {
        Write-Host "YAML does not have the expected structure" -ForegroundColor Red
    }
    
    # Output the parsed object for inspection
    Write-Host "`nParsed YAML object (ConvertTo-Json):"
    $yamlObject | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Error parsing YAML: $_" -ForegroundColor Red
}

Write-Host "`nTrying alternative parsing method (ConvertFrom-Json):"
try {
    $jsonObject = $yamlContent | ConvertFrom-Json -AsHashtable
    Write-Host "YAML parsed as JSON successfully"
    $jsonObject | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Error parsing YAML as JSON: $_" -ForegroundColor Red
}