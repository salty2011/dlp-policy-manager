function Get-DLPaCPlan {
    <#
    .SYNOPSIS
        Generates a plan of changes to be applied to DLP policies.
    
    .DESCRIPTION
        The Get-DLPaCPlan function compares the desired configuration defined in YAML files
        with the current state of DLP policies in the Microsoft 365 tenant. It generates a plan
        that details what changes will be made when Invoke-DLPaCApply is called.
    
    .PARAMETER Path
        The path to the directory containing YAML configuration files or a specific YAML file.
        If not specified, the configs directory in the current workspace is used.
    
    .PARAMETER OutputPath
        The path where the plan file should be saved. If not specified, the plan is saved in the
        .dlpac/plans directory in the current workspace.
    
    .PARAMETER Detailed
        If specified, displays a detailed plan with all changes.
    
    .PARAMETER NoConnect
        If specified, skips connecting to Exchange Online. This is useful for testing configuration
        files without connecting to the tenant.

    .PARAMETER CacheOnly
        If specified, uses only cached tenant state for generating the plan without connecting
        to Exchange Online. This enables offline planning capability.

    .PARAMETER MaxCacheAge
        Maximum age of cached state to allow when using CacheOnly mode. Default is 24 hours.
    
    .EXAMPLE
        Get-DLPaCPlan
        
        Generates a plan for all configuration files in the current workspace.
    
    .EXAMPLE
        Get-DLPaCPlan -Path "C:\DLP\configs\financial-policy.yaml" -Detailed
        
        Generates a detailed plan for the specified configuration file.
    
    .NOTES
        This function requires an initialized DLPaC workspace and appropriate permissions to
        access DLP policies in the Microsoft 365 tenant.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [string]$Path,
        
        [Parameter()]
        [string]$OutputPath,
        
        [Parameter()]
        [switch]$Detailed,
        
        [Parameter()]
        [switch]$NoConnect,

        [Parameter()]
        [switch]$CacheOnly,

        [Parameter()]
        [TimeSpan]$MaxCacheAge = [TimeSpan]::FromHours(24)
    )
    
    begin {
        # Initialize logger
        if (-not $script:Logger) {
            $script:Logger = [DLPaCLogger]::new()
        }
        
        $script:Logger.LogInfo("Starting plan generation")
        
        # Validate workspace is initialized
        if (-not $script:WorkspacePath) {
            $errorMessage = "DLPaC workspace not initialized. Run Initialize-DLPaCWorkspace first."
            $script:Logger.LogError($errorMessage)
            throw $errorMessage
        }
        
        # Set default paths if not specified
        if (-not $Path) {
            $Path = $script:Path
            if (-not $Path) {
                $Path = Join-Path $script:WorkspacePath "configs"
            }
        }
        
        if (-not $OutputPath) {
            $plansDir = Join-Path $script:WorkspacePath ".dlpac\plans"
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $OutputPath = Join-Path $plansDir "plan-$timestamp.json"
        }
        
        # Create plans directory if it doesn't exist
        $plansDir = Split-Path -Path $OutputPath -Parent
        if (-not (Test-Path $plansDir)) {
            New-Item -Path $plansDir -ItemType Directory -Force | Out-Null
        }
        
        # Initialize IPPSP adapter
        $ippspAdapter = [DLPaCIPPSPAdapter]::new($script:Logger)
    }
    
    process {
        try {
            # Create a new plan
            $plan = [DLPaCPlan]::new($OutputPath)
            
            # Load state
            $statePath = $script:StatePath
            if (-not $statePath) {
                $statePath = Join-Path $script:WorkspacePath ".dlpac\state\dlpac.state.json"
            }
            
            $script:Logger.LogInfo("Loading state from $statePath")
            $state = [DLPaCState]::Load($statePath)
            
            # Parse configuration files
            $policies = [System.Collections.ArrayList]::new()
            
            if (Test-Path $Path -PathType Container) {
                $configFiles = Get-ChildItem -Path $Path -Filter "*.yaml" -File
                $script:Logger.LogInfo("Found $($configFiles.Count) configuration files in $Path")
                
                foreach ($file in $configFiles) {
                    $script:Logger.LogInfo("Parsing configuration file: $($file.FullName)")
                    $yamlContent = Get-Content -Path $file.FullName -Raw
                    $yamlObject = $yamlContent | ConvertFrom-Yaml
                    
                    # Normalize the YAML object using the shared private function
                    $normalizedObject = Normalize-DLPaCKeys -InputObject $yamlObject
                    
                    # Ensure policies is an array
                    if ($normalizedObject.ContainsKey("policies") -and -not ($normalizedObject.policies -is [array])) {
                        $normalizedObject.policies = @($normalizedObject.policies)
                    }
                    
                    # Ensure specific nested properties are arrays
                    if ($normalizedObject.ContainsKey("policies") -and $normalizedObject.policies -is [array]) {
                        foreach ($policy in $normalizedObject.policies) {
                            if ($policy.ContainsKey("rules") -and -not ($policy.rules -is [array])) {
                                $policy.rules = @($policy.rules)
                            }
                            
                            if ($policy.ContainsKey("rules") -and $policy.rules -is [array]) {
                                foreach ($rule in $policy.rules) {
                                    if ($rule.ContainsKey("conditions") -and -not ($rule.conditions -is [array])) {
                                        $rule.conditions = @($rule.conditions)
                                    }
                                    
                                    if ($rule.ContainsKey("actions") -and -not ($rule.actions -is [array])) {
                                        $rule.actions = @($rule.actions)
                                    }
                                }
                            }
                        }
                    }
                    
                    # Validate against schema
                    $schemaValidator = [DLPaCSchemaValidator]::new((Join-Path $script:SchemaPath "policy-schema.json"))
                    if (-not $schemaValidator.ValidateYaml($normalizedObject)) {
                        $script:Logger.LogError("Configuration file $($file.Name) failed schema validation")
                        continue
                    }
                    
                    # Create policy objects
                    foreach ($policyObj in $normalizedObject.policies) {
                        $policy = [DLPaCPolicy]::FromYaml($policyObj)
                        $policies.Add($policy)
                    }
                }
            }
            elseif (Test-Path $Path -PathType Leaf) {
                $script:Logger.LogInfo("Parsing configuration file: $Path")
                $yamlContent = Get-Content -Path $Path -Raw
                $yamlObject = $yamlContent | ConvertFrom-Yaml
                
                # Normalize the YAML object using the shared private function
                $normalizedObject = Normalize-DLPaCKeys -InputObject $yamlObject
                
                # Ensure policies is an array
                if ($normalizedObject.ContainsKey("policies") -and -not ($normalizedObject.policies -is [array])) {
                    $normalizedObject.policies = @($normalizedObject.policies)
                }
                
                # Ensure specific nested properties are arrays
                if ($normalizedObject.ContainsKey("policies") -and $normalizedObject.policies -is [array]) {
                    foreach ($policy in $normalizedObject.policies) {
                        if ($policy.ContainsKey("rules") -and -not ($policy.rules -is [array])) {
                            $policy.rules = @($policy.rules)
                        }
                        
                        if ($policy.ContainsKey("rules") -and $policy.rules -is [array]) {
                            foreach ($rule in $policy.rules) {
                                if ($rule.ContainsKey("conditions") -and -not ($rule.conditions -is [array])) {
                                    $rule.conditions = @($rule.conditions)
                                }
                                
                                if ($rule.ContainsKey("actions") -and -not ($rule.actions -is [array])) {
                                    $rule.actions = @($rule.actions)
                                }
                            }
                        }
                    }
                }
                
                # Validate against schema
                $schemaValidator = [DLPaCSchemaValidator]::new((Join-Path $script:SchemaPath "policy-schema.json"))
                if (-not $schemaValidator.ValidateYaml($normalizedObject)) {
                    $script:Logger.LogError("Configuration file $Path failed schema validation")
                    throw "Configuration file failed schema validation"
                }
                
                # Create policy objects
                foreach ($policyObj in $normalizedObject.policies) {
                    $policy = [DLPaCPolicy]::FromYaml($policyObj)
                    $policies.Add($policy)
                }
            }
            else {
                $errorMessage = "Configuration path not found: $Path"
                $script:Logger.LogError($errorMessage)
                throw $errorMessage
            }
            
            $script:Logger.LogInfo("Parsed $($policies.Count) policies from configuration files")
            
            # Get current policies from tenant
            $currentPolicies = [System.Collections.ArrayList]::new()
            
            if ($CacheOnly) {
                $script:Logger.LogInfo("Using cached state only (offline mode)")
                $currentPolicies = $state.GetPoliciesFromCache()

                if (-not $currentPolicies) {
                    $errorMessage = "No cached state available for offline planning"
                    $script:Logger.LogError($errorMessage)
                    throw $errorMessage
                }

                # Validate cache age
                $cacheAge = [DateTime]::UtcNow - $state.GetLastCacheUpdate()
                if ($cacheAge -gt $MaxCacheAge) {
                    $errorMessage = "Cached state is older than maximum allowed age ($($MaxCacheAge.TotalHours) hours)"
                    $script:Logger.LogError($errorMessage)
                    throw $errorMessage
                }

                # Update plan with cache info
                $plan.SetCacheInfo($state.GetLastCacheUpdate(), $true)
            }
            elseif (-not $NoConnect) {
                $script:Logger.LogInfo("Connecting to Exchange Online to retrieve current policies")
                $connected = $ippspAdapter.Connect()
                
                if (-not $connected) {
                    $errorMessage = "Failed to connect to Exchange Online"
                    $script:Logger.LogError($errorMessage)
                    throw $errorMessage
                }
                
                $currentPolicies = $ippspAdapter.GetAllDlpPolicies()
                $script:Logger.LogInfo("Retrieved $($currentPolicies.Count) policies from tenant")
                
                # Update plan with cache info
                $plan.SetCacheInfo([DateTime]::UtcNow, $false)
            }
            else {
                $script:Logger.LogInfo("Skipping connection to Exchange Online (NoConnect specified)")
            }
            
            # Compare desired state with current state
            $script:Logger.LogInfo("Comparing desired state with current state")
            
            # Identify policies to create
            foreach ($policy in $policies) {
                $existingPolicy = $currentPolicies | Where-Object { $_.Name -eq $policy.Name } | Select-Object -First 1
                
                if (-not $existingPolicy) {
                    $script:Logger.LogInfo("Policy '$($policy.Name)' does not exist - will be created")
                    $plan.AddPolicyCreate($policy)
                    
                    # All rules will be created with the policy
                    foreach ($rule in $policy.Rules) {
                        $script:Logger.LogInfo("Rule '$($rule.Name)' in policy '$($policy.Name)' will be created")
                        $plan.AddRuleCreate($rule, $policy.Name)
                    }
                }
                else {
                    # Check if policy has changed
                    $policyChanged = $state.HasPolicyChanged($policy)
                    
                    if ($policyChanged) {
                        $script:Logger.LogInfo("Policy '$($policy.Name)' has changed - will be updated")
                        $plan.AddPolicyUpdate($policy, $existingPolicy.ToHashtable(), "Policy configuration changed")
                    }
                    
                    # Check rules
                    foreach ($rule in $policy.Rules) {
                        $existingRule = $existingPolicy.Rules | Where-Object { $_.Name -eq $rule.Name } | Select-Object -First 1
                        
                        if (-not $existingRule) {
                            $script:Logger.LogInfo("Rule '$($rule.Name)' in policy '$($policy.Name)' does not exist - will be created")
                            $plan.AddRuleCreate($rule, $policy.Name)
                        }
                        else {
                            $ruleChanged = $state.HasRuleChanged($policy.Name, $rule)
                            
                            if ($ruleChanged) {
                                $script:Logger.LogInfo("Rule '$($rule.Name)' in policy '$($policy.Name)' has changed - will be updated")
                                $plan.AddRuleUpdate($rule, $policy.Name, $existingRule.ToHashtable(), "Rule configuration changed")
                            }
                        }
                    }
                    
                    # Check for rules to delete
                    foreach ($existingRule in $existingPolicy.Rules) {
                        $ruleExists = $policy.Rules | Where-Object { $_.Name -eq $existingRule.Name } | Select-Object -First 1
                        
                        if (-not $ruleExists) {
                            $script:Logger.LogInfo("Rule '$($existingRule.Name)' in policy '$($policy.Name)' no longer exists in configuration - will be deleted")
                            $plan.AddRuleDelete($existingRule.Name, $policy.Name, $existingRule.ToHashtable())
                        }
                    }
                }
            }
            
            # Identify policies to delete
            foreach ($existingPolicy in $currentPolicies) {
                $policyExists = $policies | Where-Object { $_.Name -eq $existingPolicy.Name } | Select-Object -First 1
                
                if (-not $policyExists) {
                    $script:Logger.LogInfo("Policy '$($existingPolicy.Name)' no longer exists in configuration - will be deleted")
                    $plan.AddPolicyDelete($existingPolicy.Name, $existingPolicy.ToHashtable())
                }
            }
            
            # Save plan
            $script:Logger.LogInfo("Saving plan to $OutputPath")
            $plan.Save()
            
            # Display plan summary
            $summary = $plan.GenerateSummary()
            
            if ($Detailed) {
                # Display detailed plan
                $script:Logger.LogInfo("Detailed plan:")
                $planJson = Get-Content -Path $OutputPath -Raw
                $planObject = $planJson | ConvertFrom-Json
                $planObject | ConvertTo-Json -Depth 10
            }
            else {
                # Display summary
                $script:Logger.LogInfo("Plan summary:")
                $summary
            }
            
            # Return plan object
            [PSCustomObject]@{
                PlanPath = $OutputPath
                Summary = $summary
                HasChanges = $plan.HasChanges()
                ChangeCount = $plan.GetChangeCount()
                CreateCount = $plan.GetChangeCountByOperation("Create")
                UpdateCount = $plan.GetChangeCountByOperation("Update")
                DeleteCount = $plan.GetChangeCountByOperation("Delete")
            }
        }
        catch {
            $script:Logger.LogError("Error generating plan: $_")
            throw $_
        }
        finally {
            # Disconnect from Exchange Online if connected
            if (-not $NoConnect -and $ippspAdapter.IsConnected) {
                $script:Logger.LogInfo("Disconnecting from Exchange Online")
                $ippspAdapter.Disconnect()
            }
        }
    }
}