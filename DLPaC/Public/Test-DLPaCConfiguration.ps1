function Test-DLPaCConfiguration {
    <#
    .SYNOPSIS
        Validates DLP policy configuration files against the schema.
    
    .DESCRIPTION
        The Test-DLPaCConfiguration function validates YAML configuration files against the
        DLPaC schema. It checks for syntax errors, logical errors, and ensures the configuration
        follows the required format.
    
    .PARAMETER Path
        The path to the configuration file or directory containing configuration files to validate.
        If a directory is specified, all .yaml files in the directory will be validated.
    
    .PARAMETER Detailed
        If specified, displays detailed validation results including all errors and warnings.
    
    .EXAMPLE
        Test-DLPaCConfiguration -Path "C:\DLP\configs\financial-policy.yaml"
        
        Validates the specified configuration file.
    
    .EXAMPLE
        Test-DLPaCConfiguration -Path "C:\DLP\configs" -Detailed
        
        Validates all configuration files in the specified directory and displays detailed results.
    
    .NOTES
        This function does not require a connection to Exchange Online as it only validates
        the configuration files locally.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$Path,
        
        [Parameter()]
        [switch]$Detailed
    )
    
    begin {
        # Initialize logger
        if (-not $script:Logger) {
            $script:Logger = [DLPaCLogger]::new()
        }
        
        $script:Logger.LogInfo("Starting configuration validation")
        
        # Validate workspace is initialized
        if (-not $script:WorkspacePath) {
            $errorMessage = "DLPaC workspace not initialized. Run Initialize-DLPaCWorkspace first."
            $script:Logger.LogError($errorMessage)
            throw $errorMessage
        }
        
        # Initialize schema validator
        $schemaPath = Join-Path $script:SchemaPath "policy-schema.json"
        $schemaValidator = [DLPaCSchemaValidator]::new($schemaPath)

        # Initialize classifier validator
        $classifiersPath = Join-Path $script:WorkspacePath ".dlpac/state/classifiers.json"
        if (-not (Test-Path $classifiersPath)) {
            $script:Logger.LogWarning("Classifier cache not found at $classifiersPath. Run Initialize-DLPaCWorkspace to fetch classifiers.")
            $classifierValidator = $null
        } else {
            . "$PSScriptRoot/../Classes/ClassifierValidator.ps1"
            $classifierValidator = [DLPaCClassifierValidator]::new($classifiersPath)
        }
    }
    
    process {
        try {
            $results = [System.Collections.ArrayList]::new()
            $allCompatibilityErrorMessages = @()
            
            # Determine files to validate
            $filesToValidate = @()
            
            if (Test-Path $Path -PathType Container) {
                $filesToValidate = Get-ChildItem -Path $Path -Filter "*.yaml" -File
                $script:Logger.LogInfo("Found $($filesToValidate.Count) configuration files in $Path")
            }
            elseif (Test-Path $Path -PathType Leaf) {
                $filesToValidate = @(Get-Item -Path $Path)
                $script:Logger.LogInfo("Validating configuration file: $Path")
            }
            else {
                $errorMessage = "Path not found: $Path"
                $script:Logger.LogError($errorMessage)
                throw $errorMessage
            }
            
            # Validate each file
            foreach ($file in $filesToValidate) {
                $script:Logger.LogInfo("Validating file: $($file.FullName)")
                
                $result = [PSCustomObject]@{
                    File = $file.FullName
                    Valid = $true
                    SchemaErrors = @()
                    LogicalErrors = @()
                    Warnings = @()
                }
                
                try {
                    # Parse YAML
                    $yamlContent = Get-Content -Path $file.FullName -Raw
                    $script:Logger.LogInfo("Raw YAML content length: $($yamlContent.Length) characters")
                    
                    $yamlObject = $yamlContent | ConvertFrom-Yaml
                    
                    # Log the original parsed YAML scope values
                    if ($yamlObject.ContainsKey('policies') -and $yamlObject.policies -is [array] -and $yamlObject.policies.Count -gt 0) {
                        $firstPolicy = $yamlObject.policies[0]
                        if ($firstPolicy.ContainsKey('scope')) {
                            $script:Logger.LogInfo("Original parsed YAML - First policy scope:")
                            foreach ($scopeKey in $firstPolicy.scope.Keys) {
                                $scopeValue = $firstPolicy.scope[$scopeKey]
                                $script:Logger.LogInfo("  Original '$scopeKey': Type=$($scopeValue.GetType().FullName), Value=$($scopeValue | ConvertTo-Json -Compress)")
                            }
                        }
                    }
                    
                    # Normalize the YAML object using the shared private function
                    $normalizedObject = Normalize-DLPaCKeys -InputObject $yamlObject
                    
                    # Add diagnostic logging
                    $script:Logger.LogInfo("Original YAML structure type: $($yamlObject.GetType().FullName)")
                    $script:Logger.LogInfo("Normalized YAML structure type: $($normalizedObject.GetType().FullName)")
                    
                    # Check if policies key exists in original and normalized objects
                    $script:Logger.LogInfo("Original YAML has 'Policies' key: $($yamlObject.ContainsKey('Policies'))")
                    $script:Logger.LogInfo("Original YAML has 'policies' key: $($yamlObject.ContainsKey('policies'))")
                    $script:Logger.LogInfo("Normalized YAML has 'policies' key: $($normalizedObject.ContainsKey('policies'))")
                    
                    # Check policies type if it exists
                    if ($yamlObject.ContainsKey('Policies')) {
                        $script:Logger.LogInfo("Original 'Policies' type: $($yamlObject.Policies.GetType().FullName)")
                    }
                    if ($normalizedObject.ContainsKey('policies')) {
                        $script:Logger.LogInfo("Normalized 'policies' type: $($normalizedObject.policies.GetType().FullName)")
                        
                        # Deep dive into scope values
                        if ($normalizedObject.policies -is [array] -and $normalizedObject.policies.Count -gt 0) {
                            $firstPolicy = $normalizedObject.policies[0]
                            if ($firstPolicy.ContainsKey('scope')) {
                                $script:Logger.LogInfo("First policy has 'scope' key")
                                foreach ($scopeKey in @('exchange', 'sharepoint', 'onedrive', 'teams', 'devices')) {
                                    if ($firstPolicy.scope.ContainsKey($scopeKey)) {
                                        $scopeValue = $firstPolicy.scope[$scopeKey]
                                        $script:Logger.LogInfo("Scope '$scopeKey' type: $($scopeValue.GetType().FullName)")
                                        $script:Logger.LogInfo("Scope '$scopeKey' value: $($scopeValue | ConvertTo-Json -Compress)")
                                        
                                        # Check if it's an array and examine first element
                                        if ($scopeValue -is [array] -and $scopeValue.Count -gt 0) {
                                            $firstElement = $scopeValue[0]
                                            $script:Logger.LogInfo("  First element type: $($firstElement.GetType().FullName)")
                                            $script:Logger.LogInfo("  First element value: '$firstElement'")
                                            $script:Logger.LogInfo("  First element is bool: $($firstElement -is [bool])")
                                            $script:Logger.LogInfo("  First element is string: $($firstElement -is [string])")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    # Ensure policies is an array
                    if ($normalizedObject.ContainsKey("policies") -and -not ($normalizedObject.policies -is [array])) {
                        $script:Logger.LogInfo("Converting 'policies' to array")
                        $normalizedObject.policies = @($normalizedObject.policies)
                    }
                    
                    # Ensure specific nested properties are arrays
                    if ($normalizedObject.ContainsKey("policies") -and $normalizedObject.policies -is [array]) {
                        foreach ($policy in $normalizedObject.policies) {
                            if ($policy.ContainsKey("rules") -and -not ($policy.rules -is [array])) {
                                $script:Logger.LogInfo("Converting policy rules to array")
                                $policy.rules = @($policy.rules)
                            }
                            
                            if ($policy.ContainsKey("rules") -and $policy.rules -is [array]) {
                                foreach ($rule in $policy.rules) {
                                    if ($rule.ContainsKey("conditions") -and -not ($rule.conditions -is [array])) {
                                        $script:Logger.LogInfo("Converting rule conditions to array")
                                        $rule.conditions = @($rule.conditions)
                                    }
                                    
                                    if ($rule.ContainsKey("actions") -and -not ($rule.actions -is [array])) {
                                        $script:Logger.LogInfo("Converting rule actions to array")
                                        $rule.actions = @($rule.actions)
                                    }
                                }
                            }
                        }
                    }
                    
                    # Log the structure of the normalized object (first level)
                    $script:Logger.LogInfo("Normalized object keys: $($normalizedObject.Keys -join ', ')")
                    
                    # Validate against schema
                    $script:Logger.LogInfo("Sending normalized object to schema validator")
                    $schemaValid = $schemaValidator.ValidateYaml($normalizedObject)
                    
                    if (-not $schemaValid) {
                        $result.Valid = $false
                        $result.SchemaErrors += "Schema validation failed. See error details above."
                    }
                    
                    # Run compatibility validation
                    $workspaceRoot = if ($script:WorkspacePath) {
                        $script:WorkspacePath
                    } elseif (Test-Path $file.FullName -PathType Leaf) {
                        Split-Path -Parent $file.FullName
                    } else {
                        $PWD.Path
                    }
                    $validator = [CompatibilityValidator]::new($script:Logger, $workspaceRoot)
                    $null = $validator.LoadRules()
                    $normalizedObject._sourcePath = $file.FullName
                    $compatFindings = $validator.Evaluate($normalizedObject)

                    # Process compatibility findings
                    foreach ($finding in $compatFindings) {
                        $severity = $finding.severity.ToLower()
                        $locationInfo = ""
                        if ($finding.locations -and $finding.locations.Count -gt 0) {
                            $loc = $finding.locations[0]
                            if ($loc.filePath) { $locationInfo = " at filePath=$($loc.filePath)" }
                            if ($null -ne $loc.ruleIndex) { $locationInfo += ", ruleIndex=$($loc.ruleIndex)" }
                        } else {
                            $locationInfo = " at filePath=$($file.FullName)"
                        }
                        $formattedMessage = "[$severity] $($finding.ruleId) $($finding.policyName)/$($finding.ruleName): $($finding.message) — $($finding.suggestion)$locationInfo"
                        if ($severity -eq "error") {
                            # Avoid duplicate error logging; collect and emit once on aggregate throw
                            $allCompatibilityErrorMessages += $formattedMessage
                            $script:Logger.LogVerbose($formattedMessage)
                        } elseif ($severity -eq "warn" -or $severity -eq "warning") {
                            $script:Logger.LogWarning($formattedMessage)
                        } else {
                            $script:Logger.LogInfo($formattedMessage)
                        }
                    }

                    # Perform logical validation
                    $logicalErrors = @()
                    $warnings = @()
                    
                    # Check if policies exist
                    if (-not $yamlObject.policies -or $yamlObject.policies.Count -eq 0) {
                        $logicalErrors += "No policies defined in configuration file"
                        $result.Valid = $false
                    }
                    else {
                        # Validate each policy
                        foreach ($policy in $yamlObject.policies) {
                            # Check policy name
                            if ([string]::IsNullOrWhiteSpace($policy.name)) {
                                $logicalErrors += "Policy name cannot be empty"
                                $result.Valid = $false
                            }
                            elseif ($policy.name.Length -gt 64) {
                                $logicalErrors += "Policy name '$($policy.name)' exceeds maximum length of 64 characters"
                                $result.Valid = $false
                            }
                            
                            # Check policy mode
                            if ($policy.mode -notin @("Enable", "Test", "Disable")) {
                                $logicalErrors += "Policy '$($policy.name)' has invalid mode: $($policy.mode). Valid values are: Enable, Test, Disable"
                                $result.Valid = $false
                            }
                            
                            # Check policy priority
                            if ($policy.priority -and $policy.priority -lt 0) {
                                $logicalErrors += "Policy '$($policy.name)' has invalid priority: $($policy.priority). Priority must be a non-negative integer"
                                $result.Valid = $false
                            }
                            
                            # Check policy scope
                            if ($policy.scope) {
                                $validScopeProperties = @("exchange", "sharepoint", "onedrive", "teams", "devices")
                                
                                foreach ($scopeProp in $policy.scope.Keys) {
                                    if ($scopeProp -notin $validScopeProperties) {
                                        $warnings += "Policy '$($policy.name)' has unknown scope property: $scopeProp"
                                    }
                                }
                                
                                # Check if at least one scope is enabled
                                $scopeEnabled = $false
                                foreach ($validProp in $validScopeProperties) {
                                    if ($policy.scope.ContainsKey($validProp) -and $policy.scope[$validProp] -eq $true) {
                                        $scopeEnabled = $true
                                        break
                                    }
                                }
                                
                                if (-not $scopeEnabled) {
                                    $warnings += "Policy '$($policy.name)' has no enabled scopes. At least one scope should be enabled"
                                }
                            }
                            
                            # Check rules
                            if (-not $policy.rules -or $policy.rules.Count -eq 0) {
                                $logicalErrors += "Policy '$($policy.name)' has no rules defined"
                                $result.Valid = $false
                            }
                            else {
                                # Validate each rule
                                foreach ($rule in $policy.rules) {
                                    # Check rule name
                                    if ([string]::IsNullOrWhiteSpace($rule.name)) {
                                        $logicalErrors += "Rule name cannot be empty in policy '$($policy.name)'"
                                        $result.Valid = $false
                                    }
                                    elseif ($rule.name.Length -gt 64) {
                                        $logicalErrors += "Rule name '$($rule.name)' in policy '$($policy.name)' exceeds maximum length of 64 characters"
                                        $result.Valid = $false
                                    }
                                    
                                    # Check conditions
                                    if (-not $rule.conditions -or $rule.conditions.Count -eq 0) {
                                        $logicalErrors += "Rule '$($rule.name)' in policy '$($policy.name)' has no conditions defined"
                                        $result.Valid = $false
                                    }
                                    else {
                                        # Validate each condition
                                        foreach ($condition in $rule.conditions) {
                                            # Check condition type
                                            if (-not $condition.type) {
                                                $logicalErrors += "Condition in rule '$($rule.name)' in policy '$($policy.name)' has no type defined"
                                                $result.Valid = $false
                                            }
                                            elseif ($condition.type -notin @("ContentContainsPattern", "SensitiveInfoType", "RecipientDomain", "AccessScope")) {
                                                $logicalErrors += "Condition in rule '$($rule.name)' in policy '$($policy.name)' has invalid type: $($condition.type)"
                                                $result.Valid = $false
                                            }
                                            else {
                                                # Type-specific validation
                                                switch ($condition.type) {
                                                    "ContentContainsPattern" {
                                                        if (-not $condition.pattern) {
                                                            $logicalErrors += "ContentContainsPattern condition in rule '$($rule.name)' in policy '$($policy.name)' has no pattern defined"
                                                            $result.Valid = $false
                                                        }
                                                    }
                                                    "SensitiveInfoType" {
                                                        if (-not $condition.infoType) {
                                                            $logicalErrors += "SensitiveInfoType condition in rule '$($rule.name)' in policy '$($policy.name)' has no infoType defined"
                                                            $result.Valid = $false
                                                        } elseif ($classifierValidator -and -not $classifierValidator.IsValidInfoType($condition.infoType)) {
                                                            $logicalErrors += "InfoType '$($condition.infoType)' in rule '$($rule.name)' in policy '$($policy.name)' is not a valid classifier."
                                                            $result.Valid = $false
                                                        }
                                                    }
                                                    "RecipientDomain" {
                                                        if (-not $condition.operator) {
                                                            $logicalErrors += "RecipientDomain condition in rule '$($rule.name)' in policy '$($policy.name)' has no operator defined"
                                                            $result.Valid = $false
                                                        }
                                                        elseif ($condition.operator -notin @("Equals", "NotEquals")) {
                                                            $logicalErrors += "RecipientDomain condition in rule '$($rule.name)' in policy '$($policy.name)' has invalid operator: $($condition.operator)"
                                                            $result.Valid = $false
                                                        }
                                                        
                                                        if (-not $condition.value) {
                                                            $logicalErrors += "RecipientDomain condition in rule '$($rule.name)' in policy '$($policy.name)' has no value defined"
                                                            $result.Valid = $false
                                                        }
                                                    }
                                                    "AccessScope" {
                                                        if (-not $condition.value) {
                                                            $logicalErrors += "AccessScope condition in rule '$($rule.name)' in policy '$($policy.name)' has no value defined"
                                                            $result.Valid = $false
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    # Check actions
                                    if (-not $rule.actions -or $rule.actions.Count -eq 0) {
                                        $logicalErrors += "Rule '$($rule.name)' in policy '$($policy.name)' has no actions defined"
                                        $result.Valid = $false
                                    }
                                    else {
                                        # Validate each action
                                        foreach ($action in $rule.actions) {
                                            # Check action type
                                            if (-not $action.type) {
                                                $logicalErrors += "Action in rule '$($rule.name)' in policy '$($policy.name)' has no type defined"
                                                $result.Valid = $false
                                            }
                                            elseif ($action.type -notin @("BlockAccess", "Encrypt")) {
                                                $logicalErrors += "Action in rule '$($rule.name)' in policy '$($policy.name)' has invalid type: $($action.type)"
                                                $result.Valid = $false
                                            }
                                            else {
                                                # Type-specific validation
                                                switch ($action.type) {
                                                    "Encrypt" {
                                                        if (-not $action.encryptionMethod -and -not $action.rmsTemplate) {
                                                            $logicalErrors += "Encrypt action in rule '$($rule.name)' in policy '$($policy.name)' has no encryption template defined (use either encryptionMethod or rmsTemplate)"
                                                            $result.Valid = $false
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    $result.LogicalErrors = $logicalErrors
                    $result.Warnings = $warnings
                }
                catch {
                    $result.Valid = $false
                    $errorMsg = "Failed to parse YAML: $_"
                    $result.SchemaErrors += $errorMsg
                    $script:Logger.LogError("Failed to parse YAML in file $($file.FullName): $_")
                }
                
                $results.Add($result) | Out-Null
            }
            
            # Abort on compatibility errors collected across files
            if ($allCompatibilityErrorMessages -and $allCompatibilityErrorMessages.Count -gt 0) {
                $joined = ($allCompatibilityErrorMessages -join [Environment]::NewLine)
                throw ("Compatibility validation failed:" + [Environment]::NewLine + $joined)
            }
            # Display results summary
            foreach ($result in $results) {
                if ($result.Valid) {
                    Write-Host "✓ $($result.File) - Valid" -ForegroundColor Green
                    
                    if ($result.Warnings.Count -gt 0 -and $Detailed) {
                        Write-Host "  Warnings:" -ForegroundColor Yellow
                        foreach ($warning in $result.Warnings) {
                            Write-Host "  - $warning" -ForegroundColor Yellow
                        }
                    }
                }
                else {
                    Write-Host "✗ $($result.File) - Invalid" -ForegroundColor Red
                    
                    if ($result.SchemaErrors.Count -gt 0) {
                        Write-Host "  Schema Errors:" -ForegroundColor Red
                        foreach ($schemaError in $result.SchemaErrors) {
                            Write-Host "  - $schemaError" -ForegroundColor Red
                        }
                    }
                    
                    if ($result.LogicalErrors.Count -gt 0) {
                        Write-Host "  Logical Errors:" -ForegroundColor Red
                        foreach ($logicalError in $result.LogicalErrors) {
                            Write-Host "  - $logicalError" -ForegroundColor Red
                        }
                    }
                    
                    if ($result.Warnings.Count -gt 0) {
                        Write-Host "  Warnings:" -ForegroundColor Yellow
                        foreach ($warning in $result.Warnings) {
                            Write-Host "  - $warning" -ForegroundColor Yellow
                        }
                    }
                }
            }
            
            # Return results
            $validCount = ($results | Where-Object { $_.Valid }).Count
            $invalidCount = ($results | Where-Object { -not $_.Valid }).Count
            
            [PSCustomObject]@{
                TotalFiles = $results.Count
                ValidFiles = $validCount
                InvalidFiles = $invalidCount
                Results = $results
            }
        }
        catch {
            $msg = $_.Exception.Message
            # Avoid duplicate logging for compatibility aggregation errors; just rethrow
            if ($null -ne $msg -and $msg -like 'Compatibility validation failed:*') {
                throw $_
            }
            else {
                $script:Logger.LogError("Error validating configuration: $_")
                throw $_
            }
        }
    }
}
