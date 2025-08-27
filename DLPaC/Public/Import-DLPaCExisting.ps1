function Import-DLPaCExisting {
    <#
    .SYNOPSIS
        Imports existing DLP policies from the Microsoft 365 tenant.
    
    .DESCRIPTION
        The Import-DLPaCExisting function retrieves existing DLP policies from the Microsoft 365
        tenant and generates YAML configuration files that can be used with DLPaC. This is useful
        for migrating existing policies to the DLPaC workflow.
    
    .PARAMETER OutputPath
        The directory where the generated YAML files should be saved. If not specified, the
        configs directory in the current workspace is used.
    
    .PARAMETER PolicyName
        The name of a specific policy to import. If not specified, all policies will be imported.
    
    .PARAMETER Force
        If specified, overwrites existing configuration files.
    
    .EXAMPLE
        Import-DLPaCExisting
        
        Imports all DLP policies from the tenant and saves them to the configs directory.
    
    .EXAMPLE
        Import-DLPaCExisting -PolicyName "Financial Data Protection" -OutputPath "C:\DLP\imported" -Force
        
        Imports the specified DLP policy and saves it to the specified directory, overwriting any existing files.
    
    .NOTES
        This function requires an initialized DLPaC workspace and appropriate permissions to
        access DLP policies in the Microsoft 365 tenant.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [string]$OutputPath,
        
        [Parameter()]
        [string]$PolicyName,
        
        [Parameter()]
        [switch]$Force
    )
    
    begin {
        # Initialize logger
        if (-not $script:Logger) {
            $script:Logger = [DLPaCLogger]::new()
        }
        
        $script:Logger.LogInfo("Starting policy import")
        
        # Validate workspace is initialized
        if (-not $script:WorkspacePath) {
            $errorMessage = "DLPaC workspace not initialized. Run Initialize-DLPaCWorkspace first."
            $script:Logger.LogError($errorMessage)
            throw $errorMessage
        }
        
        # Set default output path if not specified
        if (-not $OutputPath) {
            $OutputPath = $script:ConfigPath
            if (-not $OutputPath) {
                $OutputPath = Join-Path $script:WorkspacePath "configs"
            }
        }
        
        # Create output directory if it doesn't exist
        if (-not (Test-Path $OutputPath)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        }
        
        # Initialize IPPSP adapter
        $ippspAdapter = [DLPaCIPPSPAdapter]::new($script:Logger)
    }
    
    process {
        try {
            # Connect to Exchange Online
            $script:Logger.LogInfo("Connecting to Exchange Online")
            $connected = $ippspAdapter.Connect()
            
            if (-not $connected) {
                $errorMessage = "Failed to connect to Exchange Online"
                $script:Logger.LogError($errorMessage)
                throw $errorMessage
            }
            
            # Get policies from tenant
            $policies = [System.Collections.ArrayList]::new()
            
            if ($PolicyName) {
                $script:Logger.LogInfo("Retrieving policy: $PolicyName")
                $dlpPolicies = Get-DlpCompliancePolicy -Identity $PolicyName -ErrorAction Stop
                
                if (-not $dlpPolicies) {
                    $errorMessage = "Policy '$PolicyName' not found in tenant"
                    $script:Logger.LogError($errorMessage)
                    throw $errorMessage
                }
                
                $policy = [DLPaCPolicy]::new($dlpPolicies.Name)
                $policy.Id = $dlpPolicies.Guid
                $policy.Description = $dlpPolicies.Comment
                $policy.Mode = $dlpPolicies.Mode
                $policy.Priority = $dlpPolicies.Priority
                
                # Set scope
                $policy.Scope = @{
                    exchange = $dlpPolicies.ExchangeLocation -contains "All"
                    sharepoint = $dlpPolicies.SharePointLocation -contains "All"
                    onedrive = $dlpPolicies.OneDriveLocation -contains "All"
                    teams = $dlpPolicies.TeamsLocation -contains "All"
                    devices = $dlpPolicies.EndpointDlpLocation -contains "All"
                }
                
                # Get rules for this policy
                $rules = $ippspAdapter.GetDlpRulesForPolicy($policy.Name)
                foreach ($rule in $rules) {
                    $policy.AddRule($rule)
                }
                
                $policies.Add($policy)
            }
            else {
                $script:Logger.LogInfo("Retrieving all policies")
                $policies = $ippspAdapter.GetAllDlpPolicies()
            }
            
            $script:Logger.LogInfo("Retrieved $($policies.Count) policies")
            
            # Generate YAML files
            $importedFiles = [System.Collections.ArrayList]::new()
            
            foreach ($policy in $policies) {
                $script:Logger.LogInfo("Generating YAML for policy: $($policy.Name)")
                
                # Create YAML structure
                $yamlObject = @{
                    policies = @(
                        @{
                            name = $policy.Name
                            mode = $policy.Mode
                            priority = $policy.Priority
                            description = $policy.Description
                            scope = $policy.Scope
                            rules = @()
                        }
                    )
                }
                
                # Add rules
                foreach ($rule in $policy.Rules) {
                    $ruleObject = @{
                        name = $rule.Name
                        conditions = @()
                        actions = @()
                    }
                    
                    # Add conditions
                    foreach ($condition in $rule.Conditions) {
                        $conditionObject = @{
                            type = $condition.Type
                        }
                        
                        if ($condition.Pattern) {
                            $conditionObject.pattern = $condition.Pattern
                        }
                        
                        if ($condition.InfoType) {
                            $conditionObject.infoType = $condition.InfoType
                        }
                        
                        if ($condition.MinCount -gt 0) {
                            $conditionObject.minCount = $condition.MinCount
                        }
                        
                        if ($condition.Operator) {
                            $conditionObject.operator = $condition.Operator
                        }
                        
                        if ($condition.Value) {
                            $conditionObject.value = $condition.Value
                        }
                        
                        $ruleObject.conditions += $conditionObject
                    }
                    
                    # Add actions
                    foreach ($action in $rule.Actions) {
                        $actionObject = @{
                            type = $action.Type
                        }
                        
                        if ($null -ne $action.NotifyUser) {
                            $actionObject.notifyUser = $action.NotifyUser
                        }
                        
                        if ($null -ne $action.NotifyAdmin) {
                            $actionObject.notifyAdmin = $action.NotifyAdmin
                        }
                        
                        if ($action.EncryptionMethod) {
                            $actionObject.encryptionMethod = $action.EncryptionMethod
                        }
                        
                        $ruleObject.actions += $actionObject
                    }
                    
                    $yamlObject.policies[0].rules += $ruleObject
                }
                
                # Convert to YAML
                $yaml = $yamlObject | ConvertTo-Yaml
                
                # Add header comment
                $yaml = "# DLPaC configuration for policy: $($policy.Name)`n# Imported on: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n`n$yaml"
                
                # Save to file
                $fileName = "$($policy.Name -replace '[^\w\-\.]', '_').yaml"
                $filePath = Join-Path $OutputPath $fileName
                
                if ((Test-Path $filePath) -and -not $Force) {
                    $script:Logger.LogWarning("File already exists: $filePath. Use -Force to overwrite.")
                    Write-Warning "File already exists: $filePath. Use -Force to overwrite."
                }
                else {
                    $script:Logger.LogInfo("Saving policy to: $filePath")
                    $yaml | Out-File -FilePath $filePath -Encoding utf8 -Force
                    $importedFiles.Add($filePath) | Out-Null
                }
            }
            
            # Update state file with imported policies
            $statePath = $script:StatePath
            if (-not $statePath) {
                $statePath = Join-Path $script:WorkspacePath ".dlpac\state\dlpac.state.json"
            }
            
            $script:Logger.LogInfo("Updating state file with imported policies")
            $state = [DLPaCState]::Load($statePath)
            
            # Lock state file
            $state.Lock()
            
            # Add policies to state
            foreach ($policy in $policies) {
                $state.AddPolicy($policy)
            }
            
            # Save state
            $state.Save()
            
            # Unlock state file
            $state.Unlock()
            
            # Display results
            $script:Logger.LogInfo("Import completed. Imported $($policies.Count) policies to $($importedFiles.Count) files")
            
            [PSCustomObject]@{
                ImportedPolicies = $policies.Count
                ImportedFiles = $importedFiles
                CompletedAt = Get-Date
            }
        }
        catch {
            $script:Logger.LogError("Error importing policies: $_")
            throw $_
        }
        finally {
            # Unlock state file if locked
            if ($state -and $state.IsLocked) {
                $script:Logger.LogInfo("Unlocking state file")
                $state.Unlock()
            }
            
            # Disconnect from Exchange Online if connected
            if ($ippspAdapter.IsConnected) {
                $script:Logger.LogInfo("Disconnecting from Exchange Online")
                $ippspAdapter.Disconnect()
            }
        }
    }
}