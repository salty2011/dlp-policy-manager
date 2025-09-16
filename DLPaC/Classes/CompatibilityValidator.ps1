# CompatibilityValidator.ps1
# Validates DLP configuration against compatibility rules

class CompatibilityValidator : DLPaCBaseObject {
    [DLPaCLogger]$Logger
    [string]$WorkspaceRoot
    [array]$Rules = @()

    CompatibilityValidator([DLPaCLogger]$logger, [string]$workspaceRoot) {
        $this.Logger = $logger
        $this.WorkspaceRoot = $workspaceRoot
    }

    [array] LoadRules() {
        $this.Logger.LogDebug("Loading compatibility rules")
        
        # Load default rules from module
        $moduleRulesPath = Join-Path (Join-Path $PSScriptRoot '..') 'Rules/compatibility-rules.yaml'
        
        if (-not (Test-Path $moduleRulesPath)) {
            throw "Default compatibility rules file not found: $moduleRulesPath"
        }
        
        $this.Logger.LogVerbose("Loading default rules from: $moduleRulesPath")
        $defaultRulesContent = Get-Content -Path $moduleRulesPath -Raw
        $defaultRules = ConvertFrom-Yaml $defaultRulesContent
        
        # Normalize default rules
        $normalizedDefaults = @()
        if ($defaultRules -and $defaultRules.rules) {
            foreach ($rule in $defaultRules.rules) {
                $normalizedRule = $this.NormalizeRule($rule)
                $normalizedDefaults += $normalizedRule
            }
        }
        
        # Load workspace overrides if they exist
        $overridesPath = Join-Path $this.WorkspaceRoot '.dlpac/compatibility-overrides.yaml'
        $overrideRules = @()
        
        if (Test-Path $overridesPath) {
            $this.Logger.LogVerbose("Loading override rules from: $overridesPath")
            try {
                $overridesContent = Get-Content -Path $overridesPath -Raw
                $overridesData = ConvertFrom-Yaml $overridesContent
                
                if ($overridesData -and $overridesData.rules) {
                    foreach ($rule in $overridesData.rules) {
                        $normalizedRule = $this.NormalizeRule($rule)
                        $overrideRules += $normalizedRule
                    }
                }
            }
            catch {
                $this.Logger.LogWarning("Failed to load override rules: $_")
            }
        }
        else {
            $this.Logger.LogVerbose("No override rules found at: $overridesPath")
        }
        
        # Merge rules (replace by id with case-insensitive matching)
        $mergedRules = @{}
        
        # Start with defaults
        foreach ($rule in $normalizedDefaults) {
            $id = $rule.id.ToLower()
            $mergedRules[$id] = $rule
        }
        
        # Apply overrides
        foreach ($override in $overrideRules) {
            $id = $override.id.ToLower()
            
            if ($mergedRules.ContainsKey($id)) {
                # Existing rule - overlay fields
                $existing = $mergedRules[$id]
                
                # Check if override disables the rule
                if ($override.ContainsKey('enabled') -and $override.enabled -eq $false) {
                    $existing.enabled = $false
                }
                
                # Overlay other fields if provided
                foreach ($key in @('severity', 'message', 'suggestion', 'description')) {
                    if ($override.ContainsKey($key)) {
                        $existing[$key] = $override[$key]
                    }
                }
                
                # Overlay match fields
                if ($override.ContainsKey('match')) {
                    if (-not $existing.ContainsKey('match')) {
                        $existing.match = @{}
                    }
                    foreach ($matchKey in $override.match.Keys) {
                        $existing.match[$matchKey] = $override.match[$matchKey]
                    }
                }
            }
            else {
                # New rule from override
                $mergedRules[$id] = $override
            }
        }
        
        # Filter to enabled rules only and return as array
        $enabledRules = @()
        foreach ($rule in $mergedRules.Values) {
            if ($rule.enabled -ne $false) {  # Default to enabled if not specified
                $enabledRules += $rule
            }
        }
        
        $this.Logger.LogDebug("Loaded $($enabledRules.Count) enabled compatibility rules")
        $this.Rules = $enabledRules
        return $enabledRules
    }
    
    [hashtable] NormalizeRule([hashtable]$rule) {
        # Create normalized rule with case-insensitive keys
        $normalized = @{}
        
        foreach ($key in $rule.Keys) {
            $lowerKey = $key.ToLower()
            $normalized[$lowerKey] = $rule[$key]
        }
        
        # Ensure enabled defaults to true
        if (-not $normalized.ContainsKey('enabled')) {
            $normalized.enabled = $true
        }
        
        # Normalize match fields to arrays
        if ($normalized.ContainsKey('match')) {
            $match = $normalized.match
            if ($match -is [hashtable]) {
                $normalizedMatch = @{}
                
                foreach ($matchKey in $match.Keys) {
                    $lowerMatchKey = $matchKey.ToLower()
                    $value = $match[$matchKey]
                    
                    # Coerce single items to arrays for specific fields
                    if ($lowerMatchKey -in @('actions_any_of', 'conditions_any_of', 'scopes_any_of', 'scopes_all_of')) {
                        if ($value -isnot [array]) {
                            $value = @($value)
                        }
                    }
                    
                    $normalizedMatch[$lowerMatchKey] = $value
                }
                
                $normalized.match = $normalizedMatch
            }
        }
        
        return $normalized
    }
    
    [array] Evaluate([object]$planContext) {
        $this.Logger.LogDebug("Starting compatibility evaluation")
        $findings = @()
        
        # Load rules if not already loaded
        if ($this.Rules.Count -eq 0) {
            $null = $this.LoadRules()
        }
        
        # Extract policies from planContext
        # planContext could be a Plan object or the normalized AST/policies structure
        $policies = @()
        
        if ($planContext -is [DLPaCPlan]) {
            # Extract from plan changes
            $this.Logger.LogDebug("Evaluating from Plan object")
            # For now, we need the original policies passed separately
            # This is a limitation we'll work around in the integration
            $this.Logger.LogWarning("Direct Plan evaluation not fully implemented - needs policy context")
            return @()
        }
        elseif ($planContext -is [System.Collections.ArrayList] -or $planContext -is [array]) {
            # Direct policies array
            $policies = $planContext
        }
        elseif ($planContext -is [hashtable] -and $planContext.ContainsKey('policies')) {
            # Normalized YAML structure
            $policies = $planContext.policies
        }
        else {
            $this.Logger.LogWarning("Unknown planContext type: $($planContext.GetType().FullName)")
            return @()
        }
        
        $this.Logger.LogDebug("Evaluating $($policies.Count) policies against $($this.Rules.Count) rules")
        
        # Iterate through policies and rules
        foreach ($policy in $policies) {
            # Extract policy name and scopes
            $policyName = if ($policy -is [DLPaCPolicy]) { $policy.Name }
                         elseif ($policy.ContainsKey('name')) { $policy.name }
                         else { "Unknown" }
            
            $policyScopes = @()
            
            # Extract scopes from policy
            if ($policy -is [DLPaCPolicy]) {
                # From Policy object
                $scope = $policy.Scope
                if ($scope.Exchange) { $policyScopes += "Exchange" }
                if ($scope.SharePoint) { $policyScopes += "SharePoint" }
                if ($scope.OneDrive) { $policyScopes += "OneDrive" }
                if ($scope.Teams) { $policyScopes += "Teams" }
                if ($scope.Devices) { $policyScopes += "Devices" }
            }
            elseif ($policy.ContainsKey('scope')) {
                # From normalized hashtable
                $scope = $policy.scope
                foreach ($scopeKey in @('exchange', 'sharepoint', 'onedrive', 'teams', 'devices')) {
                    if ($scope.ContainsKey($scopeKey) -and $scope[$scopeKey]) {
                        # Capitalize first letter for consistency
                        $capitalizedScope = $scopeKey.Substring(0,1).ToUpper() + $scopeKey.Substring(1).ToLower()
                        $policyScopes += $capitalizedScope
                    }
                }
            }
            
            $this.Logger.LogVerbose("Policy '$policyName' has scopes: $($policyScopes -join ', ')")
            
            # Get rules from policy
            $policyRules = @()
            if ($policy -is [DLPaCPolicy]) {
                $policyRules = $policy.Rules
            }
            elseif ($policy.ContainsKey('rules')) {
                $policyRules = $policy.rules
            }
            
            # Iterate through rules in the policy
            $ruleIndex = 0
            foreach ($rule in $policyRules) {
                $ruleName = if ($rule -is [DLPaCRule]) { $rule.Name }
                           elseif ($rule.ContainsKey('name')) { $rule.name }
                           else { "Rule$ruleIndex" }
                
                # Extract rule actions
                $ruleActions = @()
                if ($rule -is [DLPaCRule]) {
                    foreach ($action in $rule.Actions) {
                        # Try different fields to get action identifier
                        $actionId = $null
                        if ($action.Identifier) { $actionId = $action.Identifier.Trim() }
                        elseif ($action.Name) { $actionId = $action.Name.Trim() }
                        elseif ($action.Type) { $actionId = $action.Type.Trim() }

                        # Normalize Encrypt with RMS template to match compatibility rule identifier
                        # If action.Type is 'Encrypt' and an RMS template is present, treat as 'EncryptRMSTemplate'
                        try {
                            $hasRmsTemplate = $false
                            if ($null -ne $action) {
                                # For DLPaCAction objects, check EncryptionMethod property
                                if ($action | Get-Member -Name EncryptionMethod -ErrorAction SilentlyContinue) {
                                    $hasRmsTemplate = -not [string]::IsNullOrEmpty($action.EncryptionMethod)
                                }
                                # For hashtables, check rmsTemplate properties
                                elseif ($action | Get-Member -Name rmsTemplate -ErrorAction SilentlyContinue) {
                                    $hasRmsTemplate = [bool]$action.rmsTemplate
                                }
                                elseif ($action | Get-Member -Name rmstemplate -ErrorAction SilentlyContinue) {
                                    $hasRmsTemplate = [bool]$action.rmstemplate
                                }
                            }
                            if ($actionId -and $actionId -ieq 'Encrypt' -and $hasRmsTemplate) {
                                $actionId = 'EncryptRMSTemplate'
                                $this.Logger.LogDebug("Converted Encrypt action to EncryptRMSTemplate for rule '$ruleName' (DLPaCAction object)")
                            }
                        } catch {}

                        if ($actionId) { $ruleActions += $actionId }
                    }
                }
                elseif ($rule.ContainsKey('actions')) {
                    foreach ($action in $rule.actions) {
                        if ($action -is [string]) {
                            $ruleActions += $action.Trim()
                        }
                        elseif ($action -is [hashtable]) {
                            # Try different fields
                            $actionId = $null
                            foreach ($field in @('identifier', 'name', 'type')) {
                                if ($action.ContainsKey($field) -and $action[$field]) {
                                    $actionId = $action[$field].ToString().Trim()
                                    break
                                }
                            }

                            # Normalize Encrypt with RMS template to 'EncryptRMSTemplate'
                            try {
                                $typeValue = $null
                                if ($action.ContainsKey('type')) { $typeValue = $action['type'] }
                                $hasRmsTemplate = $false
                                if ($action.ContainsKey('rmsTemplate') -and $action['rmsTemplate']) { $hasRmsTemplate = $true }
                                elseif ($action.ContainsKey('rmstemplate') -and $action['rmstemplate']) { $hasRmsTemplate = $true }
                                if (($actionId -and $actionId -ieq 'Encrypt') -or ($typeValue -and $typeValue.ToString().Trim() -ieq 'Encrypt')) {
                                    if ($hasRmsTemplate) {
                                        $actionId = 'EncryptRMSTemplate'
                                        $this.Logger.LogDebug("Converted Encrypt action to EncryptRMSTemplate for rule '$ruleName'")
                                    }
                                }
                            } catch {}

                            if ($actionId) {
                                $ruleActions += $actionId
                                $this.Logger.LogDebug("Added action '$actionId' to rule '$ruleName'")
                            }
                        }
                    }
                }
                
                # Extract rule conditions (for future use with conditions_any_of)
                $ruleConditions = @()
                if ($rule -is [DLPaCRule]) {
                    foreach ($condition in $rule.Conditions) {
                        $condId = $null
                        if ($condition.Type) { $condId = $condition.Type.Trim() }
                        elseif ($condition.Name) { $condId = $condition.Name.Trim() }
                        
                        if ($condId) { $ruleConditions += $condId }
                    }
                }
                elseif ($rule.ContainsKey('conditions')) {
                    foreach ($condition in $rule.conditions) {
                        if ($condition -is [string]) {
                            $ruleConditions += $condition.Trim()
                        }
                        elseif ($condition -is [hashtable]) {
                            foreach ($field in @('type', 'name', 'identifier')) {
                                if ($condition.ContainsKey($field) -and $condition[$field]) {
                                    $condId = $condition[$field].ToString().Trim()
                                    $ruleConditions += $condId
                                    break
                                }
                            }
                        }
                    }
                }
                
                $this.Logger.LogVerbose("Rule '$ruleName' has actions: $($ruleActions -join ', ')")
                $this.Logger.LogVerbose("Rule '$ruleName' has conditions: $($ruleConditions -join ', ')")
                
                # Check against compatibility rules
                foreach ($compatRule in $this.Rules) {
                    $matched = $true
                    
                    # Check actions_any_of
                    if ($compatRule.ContainsKey('match') -and $compatRule.match.ContainsKey('actions_any_of')) {
                        $requiredActions = $compatRule.match.actions_any_of
                        $hasMatchingAction = $false
                        
                        foreach ($reqAction in $requiredActions) {
                            foreach ($ruleAction in $ruleActions) {
                                if ($reqAction -ieq $ruleAction) {
                                    $hasMatchingAction = $true
                                    break
                                }
                            }
                            if ($hasMatchingAction) { break }
                        }
                        
                        if (-not $hasMatchingAction) {
                            $matched = $false
                        }
                    }
                    
                    # Check conditions_any_of (if specified)
                    if ($matched -and $compatRule.ContainsKey('match') -and $compatRule.match.ContainsKey('conditions_any_of')) {
                        $requiredConditions = $compatRule.match.conditions_any_of
                        $hasMatchingCondition = $false
                        
                        foreach ($reqCond in $requiredConditions) {
                            foreach ($ruleCond in $ruleConditions) {
                                if ($reqCond -ieq $ruleCond) {
                                    $hasMatchingCondition = $true
                                    break
                                }
                            }
                            if ($hasMatchingCondition) { break }
                        }
                        
                        if (-not $hasMatchingCondition) {
                            $matched = $false
                        }
                    }
                    
                    # Check scopes_any_of
                    if ($matched -and $compatRule.ContainsKey('match') -and $compatRule.match.ContainsKey('scopes_any_of')) {
                        $requiredScopes = $compatRule.match.scopes_any_of
                        $hasMatchingScope = $false
                        
                        foreach ($reqScope in $requiredScopes) {
                            foreach ($policyScope in $policyScopes) {
                                if ($reqScope -ieq $policyScope) {
                                    $hasMatchingScope = $true
                                    break
                                }
                            }
                            if ($hasMatchingScope) { break }
                        }
                        
                        if (-not $hasMatchingScope) {
                            $matched = $false
                        }
                    }
                    
                    # Check scopes_all_of
                    if ($matched -and $compatRule.ContainsKey('match') -and $compatRule.match.ContainsKey('scopes_all_of')) {
                        $requiredScopes = $compatRule.match.scopes_all_of
                        
                        foreach ($reqScope in $requiredScopes) {
                            $hasScope = $false
                            foreach ($policyScope in $policyScopes) {
                                if ($reqScope -ieq $policyScope) {
                                    $hasScope = $true
                                    break
                                }
                            }
                            if (-not $hasScope) {
                                $matched = $false
                                break
                            }
                        }
                    }
                    
                    # If all match conditions are satisfied, create a finding
                    if ($matched) {
                        $finding = @{
                            policyName = $policyName
                            ruleName = $ruleName
                            ruleId = $compatRule.id
                            severity = if ($compatRule.ContainsKey('severity')) { $compatRule.severity } else { 'warning' }
                            message = if ($compatRule.ContainsKey('message')) { $compatRule.message } else { 'Compatibility issue detected' }
                            suggestion = if ($compatRule.ContainsKey('suggestion')) { $compatRule.suggestion } else { '' }
                            locations = @()
                        }
                        
                        # Try to add location info if available
                        if ($planContext -is [hashtable] -and $planContext.ContainsKey('_sourcePath')) {
                            $finding.locations += @{
                                filePath = $planContext._sourcePath
                                ruleIndex = $ruleIndex
                            }
                        }
                        
                        $findings += $finding
                        
                        $this.Logger.LogDebug("Found compatibility issue: $($compatRule.id) for $policyName/$ruleName")
                    }
                }
                
                $ruleIndex++
            }
        }
        
        $this.Logger.LogDebug("Compatibility evaluation complete. Found $($findings.Count) findings")
        return $findings
    }
}