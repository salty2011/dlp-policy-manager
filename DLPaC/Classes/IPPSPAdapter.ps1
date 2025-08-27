class DLPaCIPPSPAdapter {
    [bool] $IsConnected
    [string] $TenantId
    [string] $ConnectionMethod
    [DLPaCLogger] $Logger
    
    DLPaCIPPSPAdapter() {
        $this.IsConnected = $false
        $this.ConnectionMethod = "Interactive"
    }
    
    DLPaCIPPSPAdapter([DLPaCLogger]$Logger) {
        $this.IsConnected = $false
        $this.ConnectionMethod = "Interactive"
        $this.Logger = $Logger
    }
    
    [bool] Connect() {
        return $this.Connect($null, $null)
    }
    
    [bool] Connect([string]$TenantId, [System.Management.Automation.PSCredential]$Credential) {
        try {
            $this.Logger.LogInfo("Connecting to Exchange Online...")
            
            $connectParams = @{
                ErrorAction = "Stop"
            }
            
            if ($TenantId) {
                $connectParams.Organization = $TenantId
                $this.TenantId = $TenantId
            }
            
            if ($Credential) {
                $connectParams.Credential = $Credential
                $this.ConnectionMethod = "Credential"
            }
            else {
                $this.ConnectionMethod = "Interactive"
            }
            
            # Check if already connected
            try {
                $null = Get-IPPSSession -ErrorAction Stop
                $this.Logger.LogInfo("Already connected to Exchange Online")
                $this.IsConnected = $true
                return $true
            }
            catch {
                # Not connected, continue with connection
            }
            
            # Connect to Exchange Online
            Connect-IPPSSession @connectParams
            
            $this.Logger.LogInfo("Successfully connected to Exchange Online")
            $this.IsConnected = $true
            return $true
        }
        catch {
            $this.Logger.LogError("Failed to connect to Exchange Online: $_")
            $this.IsConnected = $false
            return $false
        }
    }
    
    [void] Disconnect() {
        try {
            if ($this.IsConnected) {
                $this.Logger.LogInfo("Disconnecting from Exchange Online...")
                Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
                $this.IsConnected = $false
                $this.Logger.LogInfo("Disconnected from Exchange Online")
            }
        }
        catch {
            $this.Logger.LogWarning("Error during disconnection: $_")
        }
    }
    
    [System.Collections.ArrayList] GetAllDlpPolicies() {
        $policies = [System.Collections.ArrayList]::new()
        
        try {
            $this.EnsureConnected()
            
            $this.Logger.LogInfo("Retrieving all DLP policies...")
            $dlpPolicies = Get-DlpCompliancePolicy
            
            foreach ($dlpPolicy in $dlpPolicies) {
                $policy = [DLPaCPolicy]::new($dlpPolicy.Name)
                $policy.Id = $dlpPolicy.Guid
                $policy.Description = $dlpPolicy.Comment
                $policy.Mode = $dlpPolicy.Mode
                $policy.Priority = $dlpPolicy.Priority
                
                # Set scope
                $policy.Scope = @{
                    exchange = $dlpPolicy.ExchangeLocation -contains "All"
                    sharepoint = $dlpPolicy.SharePointLocation -contains "All"
                    onedrive = $dlpPolicy.OneDriveLocation -contains "All"
                    teams = $dlpPolicy.TeamsLocation -contains "All"
                    devices = $dlpPolicy.EndpointDlpLocation -contains "All"
                }
                
                # Get rules for this policy
                $rules = $this.GetDlpRulesForPolicy($policy.Name)
                foreach ($rule in $rules) {
                    $policy.AddRule($rule)
                }
                
                $policy.UpdateHash()
                $policies.Add($policy)
            }
            
            $this.Logger.LogInfo("Retrieved $($policies.Count) DLP policies")
            return $policies
        }
        catch {
            $this.Logger.LogError("Error retrieving DLP policies: $_")
            throw $_
        }
    }
    
    [System.Collections.ArrayList] GetDlpRulesForPolicy([string]$PolicyName) {
        $rules = [System.Collections.ArrayList]::new()
        
        try {
            $this.EnsureConnected()
            
            $this.Logger.LogInfo("Retrieving DLP rules for policy '$PolicyName'...")
            $dlpRules = Get-DlpComplianceRule -Policy $PolicyName
            
            foreach ($dlpRule in $dlpRules) {
                $this.Logger.LogInfo("DEBUG: Rule properties for $($dlpRule.Name): Guid=$($dlpRule.Guid), Identity=$($dlpRule.Identity), Id=$($dlpRule.Id), Name=$($dlpRule.Name)")
                $rule = [DLPaCRule]::new($dlpRule.Name)
                $rule.Id = $dlpRule.Guid
                if (-not $rule.Id) {
                    $rule.Id = $dlpRule.Identity
                }
                if (-not $rule.Id) {
                    $rule.Id = $dlpRule.Id
                }
                if (-not $rule.Id) {
                    $rule.Id = $dlpRule.Name
                }
                $this.Logger.LogInfo("DEBUG: Selected Rule.Id for $($dlpRule.Name): $($rule.Id)")
                $rule.PolicyName = $PolicyName
                
                # Process conditions
                if ($dlpRule.ContentContainsSensitiveInformation) {
                    foreach ($sensitiveInfo in $dlpRule.ContentContainsSensitiveInformation) {
                        $condition = [DLPaCCondition]::new("SensitiveInfoType")
                        $condition.InfoType = $sensitiveInfo.Name
                        $condition.MinCount = $sensitiveInfo.MinCount
                        $rule.AddCondition($condition)
                    }
                }
                
                if ($dlpRule.RecipientDomainIs) {
                    $condition = [DLPaCCondition]::new("RecipientDomain")
                    $condition.Operator = "Equals"
                    $condition.Value = $dlpRule.RecipientDomainIs
                    $rule.AddCondition($condition)
                }
                
                if ($dlpRule.RecipientDomainIsNot) {
                    $condition = [DLPaCCondition]::new("RecipientDomain")
                    $condition.Operator = "NotEquals"
                    $condition.Value = $dlpRule.RecipientDomainIsNot
                    $rule.AddCondition($condition)
                }
                
                if ($dlpRule.AccessScope) {
                    $condition = [DLPaCCondition]::new("AccessScope")
                    $condition.Value = $dlpRule.AccessScope
                    $rule.AddCondition($condition)
                }
                
                # Process actions
                if ($dlpRule.BlockAccess) {
                    $action = [DLPaCAction]::new("BlockAccess")
                    $action.NotifyUser = $dlpRule.NotifyUser
                    $action.NotifyAdmin = $dlpRule.NotifyAdmin
                    $rule.AddAction($action)
                }
                
                if ($dlpRule.Encrypt) {
                    $action = [DLPaCAction]::new("Encrypt")
                    # Use EncryptRMSTemplate instead of EncryptionMethod
                    $action.EncryptionMethod = $dlpRule.EncryptRMSTemplate
                    $rule.AddAction($action)
                }
                
                $rule.UpdateHash()
                $rules.Add($rule)
            }
            
            $this.Logger.LogInfo("Retrieved $($rules.Count) DLP rules for policy '$PolicyName'")
            return $rules
        }
        catch {
            $this.Logger.LogError("Error retrieving DLP rules for policy '$PolicyName': $_")
            throw $_
        }
    }
    
    [void] CreatePolicy([DLPaCPolicy]$Policy) {
        try {
            $this.EnsureConnected()
            
            $this.Logger.LogInfo("Creating DLP policy '$($Policy.Name)'...")
            $params = $Policy.ToIPPSPParameters()
            
            # Log the exact command being executed for debugging
            $paramsString = ($params.GetEnumerator() | ForEach-Object { "-$($_.Key) '$($_.Value)'" }) -join " "
            Write-Host "COMMAND TO BE EXECUTED: New-DlpCompliancePolicy $paramsString" -ForegroundColor Cyan
            $this.Logger.LogInfo("COMMAND TO BE EXECUTED: New-DlpCompliancePolicy $paramsString")
            
            # Try creating the policy with modified parameters
            try {
                # Create a copy of the parameters
                $modifiedParams = @{}
                foreach ($key in $params.Keys) {
                    $modifiedParams[$key] = $params[$key]
                }
                
                # Remove problematic parameters
                if ($modifiedParams.ContainsKey("ExchangeLocation")) {
                    Write-Host "REMOVING PARAMETER: ExchangeLocation" -ForegroundColor Yellow
                    $this.Logger.LogInfo("REMOVING PARAMETER: ExchangeLocation")
                    $modifiedParams.Remove("ExchangeLocation")
                }
                
                # Log the modified command
                $modifiedParamsString = ($modifiedParams.GetEnumerator() | ForEach-Object { "-$($_.Key) '$($_.Value)'" }) -join " "
                Write-Host "MODIFIED COMMAND TO BE EXECUTED: New-DlpCompliancePolicy $modifiedParamsString" -ForegroundColor Green
                $this.Logger.LogInfo("MODIFIED COMMAND TO BE EXECUTED: New-DlpCompliancePolicy $modifiedParamsString")
                
                # Create the policy with modified parameters
                $newPolicy = New-DlpCompliancePolicy @modifiedParams
                
                # Only log success if we actually get a policy object back
                if ($newPolicy -and $newPolicy.Guid) {
                    $Policy.Id = $newPolicy.Identity
                    $this.Logger.LogInfo("DLP policy '$($Policy.Name)' created successfully with ID: $($Policy.Id)")
                }
                else {
                    $errorMsg = "Policy creation appeared to succeed but no valid policy object was returned"
                    $this.Logger.LogError($errorMsg)
                    throw $errorMsg
                }
            }
            catch {
                $this.Logger.LogError("Failed to create policy with modified parameters: $_")
                throw
            }
            
            # Wait for policy to propagate before creating rules
            $this.Logger.LogInfo("Waiting for policy '$($Policy.Name)' to propagate before creating rules...")
            $maxAttempts = 10
            $delaySeconds = 5
            $policyFound = $false
            
            for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
                try {
                    $this.Logger.LogInfo("Checking if policy '$($Policy.Name)' is available (attempt $attempt of $maxAttempts)...")
                    $existingPolicy = Get-DlpCompliancePolicy -Identity $Policy.Name -ErrorAction Stop
                    
                    if ($existingPolicy) {
                        $this.Logger.LogInfo("Policy '$($Policy.Name)' is now available. Proceeding with rule creation.")
                        $Policy.Id = $existingPolicy.Identity
                        $policyFound = $true
                        break
                    }
                }
                catch {
                    $this.Logger.LogWarning("Policy '$($Policy.Name)' not yet available: $_. Waiting $delaySeconds seconds...")
                }
                
                if ($attempt -lt $maxAttempts) {
                    Start-Sleep -Seconds $delaySeconds
                }
            }
            
            if (-not $policyFound) {
                $this.Logger.LogWarning("Could not confirm policy '$($Policy.Name)' is available after $maxAttempts attempts. Will attempt to create rules anyway.")
            }
            
            # Create rules
            foreach ($rule in $Policy.Rules) {
                $rule.PolicyName = $Policy.Name
                try {
                    $this.CreateRule($rule)
                }
                catch {
                    $this.Logger.LogError("Error creating rule '$($rule.Name)': $_. Will retry once more after delay.")
                    Start-Sleep -Seconds $delaySeconds
                    $this.CreateRule($rule)
                }
            }
        }
        catch {
            $this.Logger.LogError("Error creating DLP policy '$($Policy.Name)': $_")
            throw $_
        }
    }
    
    [void] UpdatePolicy([DLPaCPolicy]$Policy) {
        try {
            $this.EnsureConnected()
            
            $this.Logger.LogInfo("Updating DLP policy '$($Policy.Name)'...")

            # Ensure Policy.Id is set
            if (-not $Policy.Id) {
                $existingPolicy = Get-DlpCompliancePolicy -Identity $Policy.Name -ErrorAction SilentlyContinue
                if ($existingPolicy) {
                    $Policy.Id = $existingPolicy.Guid
                    #$this.Logger.LogInfo("DEBUG: Set Policy.Id to $($Policy.Id) from Get-DlpCompliancePolicy")
                }
            }

            $params = $Policy.ToIPPSPParameters($true)
            
            # Remove Name parameter and add Identity parameter
            if ($params.ContainsKey("Name")) {
                $params.Remove("Name")
            }
            $this.Logger.LogInfo("DEBUG: Using Policy.Id for Identity: $($Policy.Id)")
            $params.Identity = $Policy.Id
            
            # Log the exact command being executed for debugging
            $paramsString = ($params.GetEnumerator() | ForEach-Object { "-$($_.Key) '$($_.Value)'" }) -join " "
            Write-Host "POLICY UPDATE COMMAND TO BE EXECUTED: Set-DlpCompliancePolicy $paramsString" -ForegroundColor Cyan
            $this.Logger.LogInfo("POLICY UPDATE COMMAND TO BE EXECUTED: Set-DlpCompliancePolicy $paramsString")
            
            Set-DlpCompliancePolicy @params
            
            $this.Logger.LogInfo("DLP policy '$($Policy.Name)' updated successfully")
            
            # Handle rules
            $existingRules = $this.GetDlpRulesForPolicy($Policy.Name)
            $existingRuleNames = $existingRules | ForEach-Object { $_.Name }
            
            # Create or update rules
            foreach ($rule in $Policy.Rules) {
                $rule.PolicyName = $Policy.Name
                
                if ($existingRuleNames -contains $rule.Name) {
                    $this.UpdateRule($rule)
                }
                else {
                    $this.CreateRule($rule)
                }
            }
            
            # Delete rules that no longer exist
            $currentRuleNames = $Policy.Rules | ForEach-Object { $_.Name }
            foreach ($existingRule in $existingRules) {
                if ($currentRuleNames -notcontains $existingRule.Name) {
                    $this.DeleteRule($existingRule)
                }
            }
        }
        catch {
            $this.Logger.LogError("Error updating DLP policy '$($Policy.Name)': $_")
            throw $_
        }
    }
    
    [void] DeletePolicy([string]$PolicyName) {
        try {
            $this.EnsureConnected()
            
            $this.Logger.LogInfo("Deleting DLP policy '$PolicyName'...")
            
            # First check if the policy exists
            try {
                $policy = Get-DlpCompliancePolicy -Identity $PolicyName -ErrorAction Stop
                if (-not $policy) {
                    $this.Logger.LogInfo("DLP policy '$PolicyName' not found. Considering deletion successful.")
                    return
                }
            }
            catch {
                # Check if it's an ItemNotFoundException or contains "not found" in the error message
                if ($_ -is [System.Management.Automation.ItemNotFoundException] -or
                    $_.Exception.Message -like "*not found*" -or
                    $_.Exception.Message -like "*doesn't exist*" -or
                    $_.Exception.Message -like "*could not be found*") {
                    $this.Logger.LogInfo("DLP policy '$PolicyName' not found. Considering deletion successful.")
                    return
                }
                
                # Other errors - continue with deletion attempt
                $this.Logger.LogWarning("Error checking if policy exists: $_. Proceeding with deletion attempt.")
            }
            
            # Delete the policy
            try {
                Remove-DlpCompliancePolicy -Identity $PolicyName -Confirm:$false -ErrorAction Stop
                $this.Logger.LogInfo("Delete command for policy '$PolicyName' executed successfully.")
            }
            catch {
                # Check if it's an ItemNotFoundException or contains "not found" in the error message
                if ($_ -is [System.Management.Automation.ItemNotFoundException] -or
                    $_.Exception.Message -like "*not found*" -or
                    $_.Exception.Message -like "*doesn't exist*" -or
                    $_.Exception.Message -like "*could not be found*") {
                    $this.Logger.LogInfo("DLP policy '$PolicyName' not found during deletion. Considering deletion successful.")
                    return
                }
                
                # Handle JSON parse errors
                if ($_.Exception.Message -like "*Unexpected character encountered while parsing value*") {
                    $this.Logger.LogWarning("Received unexpected response format during deletion. Will check if policy was deleted anyway.")
                }
                else {
                    $this.Logger.LogWarning("Error during initial deletion attempt: $_. Will check if policy was deleted anyway.")
                }
            }
            
            # Poll to check if the policy has been deleted
            $maxAttempts = 10
            $delaySeconds = 5
            $deleted = $false
            
            for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
                $this.Logger.LogInfo("Checking if policy '$PolicyName' has been deleted (attempt $attempt of $maxAttempts)...")
                
                try {
                    $policy = Get-DlpCompliancePolicy -Identity $PolicyName -ErrorAction Stop
                    if (-not $policy) {
                        $deleted = $true
                        break
                    }
                }
                catch {
                    # Check if it's an ItemNotFoundException or contains "not found" in the error message
                    if ($_ -is [System.Management.Automation.ItemNotFoundException] -or
                        $_.Exception.Message -like "*not found*" -or
                        $_.Exception.Message -like "*doesn't exist*" -or
                        $_.Exception.Message -like "*could not be found*") {
                        $deleted = $true
                        break
                    }
                    
                    # Handle JSON parse errors
                    if ($_.Exception.Message -like "*Unexpected character encountered while parsing value*") {
                        $this.Logger.LogWarning("Received unexpected response format. Will retry.")
                    }
                    else {
                        $this.Logger.LogWarning("Error checking if policy was deleted: $_. Will retry.")
                    }
                }
                
                if ($attempt -lt $maxAttempts) {
                    $this.Logger.LogInfo("Policy '$PolicyName' still exists or status unknown. Waiting $delaySeconds seconds before checking again...")
                    Start-Sleep -Seconds $delaySeconds
                }
            }
            
            if ($deleted) {
                $this.Logger.LogInfo("DLP policy '$PolicyName' deleted successfully")
            }
            else {
                $this.Logger.LogWarning("Could not confirm deletion of policy '$PolicyName' after $maxAttempts attempts. The operation may still complete in the background.")
            }
        }
        catch {
            $this.Logger.LogError("Error deleting DLP policy '$PolicyName': $_")
            throw $_
        }
    }
    
    [void] CreateRule([DLPaCRule]$Rule) {
        try {
            $this.EnsureConnected()
            
            $this.Logger.LogInfo("Creating DLP rule '$($Rule.Name)' for policy '$($Rule.PolicyName)'...")
            $params = $Rule.ToIPPSPParameters($true)
            
            # Log the exact command being executed for debugging
            $paramsString = ($params.GetEnumerator() | ForEach-Object {
                $key = $_.Key
                $value = $_.Value
                
                # Handle ContentContainsSensitiveInformation specially
                if ($key -eq "ContentContainsSensitiveInformation") {
                    $sensitiveInfoString = "@("
                    foreach ($item in $value) {
                        $sensitiveInfoString += "@{Name='$($item.Name)'; MinCount=$($item.MinCount)},"
                    }
                    $sensitiveInfoString = $sensitiveInfoString.TrimEnd(',') + ")"
                    "-$key $sensitiveInfoString"
                }
                else {
                    "-$key '$value'"
                }
            }) -join " "
            
            Write-Host "RULE COMMAND TO BE EXECUTED: New-DlpComplianceRule $paramsString" -ForegroundColor Cyan
            $this.Logger.LogInfo("RULE COMMAND TO BE EXECUTED: New-DlpComplianceRule $paramsString")
            
            $newRule = New-DlpComplianceRule @params
            $Rule.Id = $newRule.Guid
            
            $this.Logger.LogInfo("DLP rule '$($Rule.Name)' created successfully with ID: $($Rule.Id)")
        }
        catch {
            $this.Logger.LogError("Error creating DLP rule '$($Rule.Name)': $_")
            throw $_
        }
    }
    
    [void] UpdateRule([DLPaCRule]$Rule) {
        try {
            $this.EnsureConnected()
            
            $this.Logger.LogInfo("Updating DLP rule '$($Rule.Name)' for policy '$($Rule.PolicyName)'...")

            # Ensure Rule.Id is set by looking up the rule in the tenant if necessary
            if (-not $Rule.Id) {
                $existingRules = Get-DlpComplianceRule -Policy $Rule.PolicyName
                $existingRule = $existingRules | Where-Object { $_.Name -eq $Rule.Name }
                if ($existingRule) {
                    $Rule.Id = $existingRule.Guid
                    if (-not $Rule.Id) { $Rule.Id = $existingRule.Identity }
                    if (-not $Rule.Id) { $Rule.Id = $existingRule.Id }
                    if (-not $Rule.Id) { $Rule.Id = $existingRule.Name }
                    $this.Logger.LogInfo("DEBUG: Looked up Rule.Id for $($Rule.Name): $($Rule.Id)")
                }
            }

            $params = $Rule.ToIPPSPParameters()
            if ($params.ContainsKey("Policy")) {
                $params.Remove("Policy")
            }
            if ($params.ContainsKey("Name")) {
                $params.Remove("Name")
            }
            $params.Identity = $Rule.Id
            $this.Logger.LogInfo("DEBUG: Using Rule.Id for Identity: $($params.Identity)")
            $paramsString = ($params.GetEnumerator() | ForEach-Object {
                $key = $_.Key
                $value = $_.Value
                if ($key -eq "ContentContainsSensitiveInformation" -and $value -is [array]) {
                    $sensitiveInfoString = "@("
                    foreach ($item in $value) {
                        $sensitiveInfoString += "@{"
                        $sensitiveInfoString += ($item.GetEnumerator() | ForEach-Object { "$($_.Key)='$($_.Value)'" }) -join "; "
                        $sensitiveInfoString += "},"
                    }
                    $sensitiveInfoString = $sensitiveInfoString.TrimEnd(',') + ")"
                    "-$key $sensitiveInfoString"
                } else {
                    "-$key '$value'"
                }
            }) -join " "
            $this.Logger.LogInfo("DEBUG: Set-DlpComplianceRule params: $paramsString")
            
            Set-DlpComplianceRule @params -Confirm:$false
            
            $this.Logger.LogInfo("DLP rule '$($Rule.Name)' updated successfully")
        }
        catch {
            $this.Logger.LogError("Error updating DLP rule '$($Rule.Name)': $_")
            throw $_
        }
    }
    
    [void] DeleteRule([DLPaCRule]$Rule) {
        try {
            $this.EnsureConnected()
            
            $this.Logger.LogInfo("Deleting DLP rule '$($Rule.Name)' from policy '$($Rule.PolicyName)'...")
            
            Remove-DlpComplianceRule -Identity $Rule.Name -Confirm:$false
            
            $this.Logger.LogInfo("DLP rule '$($Rule.Name)' deleted successfully")
        }
        catch {
            $this.Logger.LogError("Error deleting DLP rule '$($Rule.Name)': $_")
            throw $_
        }
    }
    
    [void] EnsureConnected() {
        if (-not $this.IsConnected) {
            $connected = $this.Connect()
            if (-not $connected) {
                throw "Not connected to Exchange Online. Please connect first using Connect-DLPaC."
            }
        }
    }
}