class DLPaCState {
    [hashtable] $Metadata
    [hashtable] $Policies
    [string] $StatePath
    [bool] $IsLocked
    [hashtable] $TenantCache
    hidden [string] $CachePath
    
    DLPaCState() {
        $this.Metadata = @{
            version = "1.0.0"
            lastRun = [datetime]::UtcNow.ToString('o')
            tenant = ""
            environment = ""
        }
        
        $this.Policies = @{}
        $this.IsLocked = $false
        $this.TenantCache = @{}
    }
    
    DLPaCState([string]$StatePath) {
        $this.Metadata = @{
            version = "1.0.0"
            lastRun = [datetime]::UtcNow.ToString('o')
            tenant = ""
            environment = ""
        }
        
        $this.Policies = @{}
        $this.StatePath = $StatePath
        $this.IsLocked = $false
        $this.TenantCache = @{}
        $this.CachePath = Join-Path (Split-Path $StatePath) ".tenant-cache.json"
    }
    
    [void] Initialize([string]$TenantName, [string]$Environment) {
        $this.Metadata.tenant = $TenantName
        $this.Metadata.environment = $Environment
        $this.Metadata.lastRun = [datetime]::UtcNow.ToString('o')
    }
    
    [void] AddPolicy([DLPaCPolicy]$Policy) {
        if (-not $this.Policies.ContainsKey($Policy.Name)) {
            $this.Policies[$Policy.Name] = @{
                id = $Policy.Id
                name = $Policy.Name
                hash = $Policy.Hash
                lastApplied = [datetime]::UtcNow.ToString('o')
                rules = @{}
            }
        }
        else {
            $this.Policies[$Policy.Name].hash = $Policy.Hash
            $this.Policies[$Policy.Name].lastApplied = [datetime]::UtcNow.ToString('o')
            
            if ($Policy.Id) {
                $this.Policies[$Policy.Name].id = $Policy.Id
            }
        }
        
        # Add rules
        foreach ($rule in $Policy.Rules) {
            $this.AddRule($Policy.Name, $rule)
        }
    }
    
    [void] AddRule([string]$PolicyName, [DLPaCRule]$Rule) {
        if (-not $this.Policies.ContainsKey($PolicyName)) {
            throw "Policy '$PolicyName' not found in state"
        }
        
        if (-not $this.Policies[$PolicyName].rules.ContainsKey($Rule.Name)) {
            $this.Policies[$PolicyName].rules[$Rule.Name] = @{
                id = $Rule.Id
                hash = $Rule.Hash
            }
        }
        else {
            $this.Policies[$PolicyName].rules[$Rule.Name].hash = $Rule.Hash
            
            if ($Rule.Id) {
                $this.Policies[$PolicyName].rules[$Rule.Name].id = $Rule.Id
            }
        }
    }
    
    [void] RemovePolicy([string]$PolicyName) {
        if ($this.Policies.ContainsKey($PolicyName)) {
            $this.Policies.Remove($PolicyName)
        }
    }
    
    [void] RemoveRule([string]$PolicyName, [string]$RuleName) {
        if ($this.Policies.ContainsKey($PolicyName) -and 
            $this.Policies[$PolicyName].rules.ContainsKey($RuleName)) {
            $this.Policies[$PolicyName].rules.Remove($RuleName)
        }
    }
    
    [bool] HasPolicyChanged($Policy) {
        # Handle type conversion issues by using the Name property directly
        $policyName = $Policy.Name
        
        if (-not $this.Policies.ContainsKey($policyName)) {
            return $true  # New policy
        }
        
        # Compare configuration state only to detect intentional changes
        $configHash = $Policy.GenerateConfigHash()
        $storedHash = $this.Policies[$policyName].hash
        
        # If hashes match, check tenant cache for applied state
        if ($configHash -eq $storedHash -and $this.TenantCache.ContainsKey($policyName)) {
            $cachedState = $this.TenantCache[$policyName]
            if ($cachedState.LastApplied -gt [datetime]::Parse($this.Policies[$policyName].lastApplied)) {
                return $true # Tenant state changed after our last apply
            }
        }
        
        return $configHash -ne $storedHash
    }
    
    [bool] HasRuleChanged([string]$PolicyName, $Rule) {
        # Handle type conversion issues by using the Name property directly
        $ruleName = $Rule.Name
        
        if (-not $this.Policies.ContainsKey($PolicyName) -or
            -not $this.Policies[$PolicyName].rules.ContainsKey($ruleName)) {
            return $true  # New rule
        }
        
        return $this.Policies[$PolicyName].rules[$ruleName].hash -ne $Rule.Hash
    }
    
    [string] GetPolicyId([string]$PolicyName) {
        if ($this.Policies.ContainsKey($PolicyName) -and $this.Policies[$PolicyName].id) {
            return $this.Policies[$PolicyName].id
        }
        
        return $null
    }
    
    [string] GetRuleId([string]$PolicyName, [string]$RuleName) {
        if ($this.Policies.ContainsKey($PolicyName) -and 
            $this.Policies[$PolicyName].rules.ContainsKey($RuleName) -and
            $this.Policies[$PolicyName].rules[$RuleName].id) {
            return $this.Policies[$PolicyName].rules[$RuleName].id
        }
        
        return $null
    }
    
    [void] SaveTenantCache() {
        if (-not $this.CachePath) {
            throw "Cache path not set"
        }
        
        $cacheObject = @{
            lastUpdated = [datetime]::UtcNow.ToString('o')
            policies = $this.TenantCache
        }
        
        $cacheJson = $cacheObject | ConvertTo-Json -Depth 10
        $cacheJson | Out-File -FilePath $this.CachePath -Encoding utf8 -Force
    }
    
    [void] LoadTenantCache() {
        if (Test-Path $this.CachePath) {
            try {
                $cacheJson = Get-Content -Path $this.CachePath -Raw
                $cacheObject = $cacheJson | ConvertFrom-Json -AsHashtable
                
                if ($cacheObject.policies) {
                    $this.TenantCache = $cacheObject.policies
                }
            }
            catch {
                Write-Warning "Failed to load tenant cache: $_"
                $this.TenantCache = @{}
            }
        }
    }
    
    [void] UpdateTenantCache([string]$PolicyName, [hashtable]$State) {
        $this.TenantCache[$PolicyName] = @{
            LastApplied = [datetime]::UtcNow
            State = $State
        }
        $this.SaveTenantCache()
    }
    
    [void] InvalidateCache([string]$PolicyName) {
        if ($this.TenantCache.ContainsKey($PolicyName)) {
            $this.TenantCache.Remove($PolicyName)
            $this.SaveTenantCache()
        }
    }
    
    [void] Save() {
        if (-not $this.StatePath) {
            throw "State path not set"
        }
        
        # Update metadata
        $this.Metadata.lastRun = [datetime]::UtcNow.ToString('o')
        
        # Create state object
        $stateObject = @{
            metadata = $this.Metadata
            policies = $this.Policies
        }
        
        # Create backup of existing state file
        if (Test-Path $this.StatePath) {
            $backupPath = "$($this.StatePath).backup"
            Copy-Item -Path $this.StatePath -Destination $backupPath -Force
        }
        
        # Save state to file
        $stateJson = $stateObject | ConvertTo-Json -Depth 10
        $stateJson | Out-File -FilePath $this.StatePath -Encoding utf8 -Force
    }
    
    [void] Lock() {
        if (-not $this.StatePath) {
            throw "State path not set"
        }
        
        $lockPath = "$($this.StatePath).lock"
        
        if (Test-Path $lockPath) {
            $lockContent = Get-Content $lockPath -Raw
            throw "State file is locked by process: $lockContent"
        }
        
        $lockInfo = @{
            pid = $global:PID
            timestamp = [datetime]::UtcNow.ToString('o')
            user = $env:USERNAME
        } | ConvertTo-Json
        
        $lockInfo | Out-File -FilePath $lockPath -Encoding utf8 -Force
        $this.IsLocked = $true
    }
    
    [void] Unlock() {
        if (-not $this.StatePath) {
            return
        }
        
        $lockPath = "$($this.StatePath).lock"
        
        if (Test-Path $lockPath) {
            Remove-Item $lockPath -Force
        }
        
        $this.IsLocked = $false
    }
    
    static [DLPaCState] Load([string]$StatePath) {
        $state = [DLPaCState]::new($StatePath)
        
        if (Test-Path $StatePath) {
            try {
                $stateJson = Get-Content -Path $StatePath -Raw
                $stateObject = $stateJson | ConvertFrom-Json -AsHashtable
                
                if ($stateObject.metadata) {
                    $state.Metadata = $stateObject.metadata
                }
                
                if ($stateObject.policies) {
                    $state.Policies = $stateObject.policies
                }
            }
            catch {
                throw "Failed to load state file: $_"
            }
        }
        
        return $state
    }
}