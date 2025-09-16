class DLPaCPolicy : DLPaCBaseObject {
    [string] $Description
    [string] $Mode # Enable, Test, or Disable
    [int] $Priority
    [hashtable] $Scope
    [System.Collections.ArrayList] $Rules
    
    DLPaCPolicy() : base() {
        $this.Rules = [System.Collections.ArrayList]::new()
        $this.Scope = @{
            exchange = @()
            sharepoint = @()
            onedrive = @()
            teams = @()
            devices = @()
        }
        $this.Mode = "Enable"
        $this.Priority = 0
    }
    
    DLPaCPolicy([string]$Name) : base($Name) {
        $this.Rules = [System.Collections.ArrayList]::new()
        $this.Scope = @{
            exchange = @()
            sharepoint = @()
            onedrive = @()
            teams = @()
            devices = @()
        }
        $this.Mode = "Enable"
        $this.Priority = 0
    }
    
    [void] AddRule([DLPaCRule]$Rule) {
        $this.Rules.Add($Rule)
        $this.UpdateHash()
    }
    
    [void] RemoveRule([string]$RuleName) {
        $ruleToRemove = $this.Rules | Where-Object { $_.Name -eq $RuleName }
        if ($ruleToRemove) {
            $this.Rules.Remove($ruleToRemove)
            $this.UpdateHash()
        }
    }
    
    [string] GenerateHash([bool]$includeAppliedState = $true) {
        # Include both configuration and applied state in hash calculation
        $hashInput = @{
            # Configuration state
            Name = $this.Name
            Description = $this.Description
            Mode = $this.Mode
            Priority = $this.Priority
            Scope = $this.Scope
            Rules = $this.Rules | ForEach-Object { $_.ToHashtable() }
        }
        
        if ($includeAppliedState) {
            $hashInput.AppliedState = @{
                Id = $this.Id
                LastModified = $this.LastModified
                Rules = $this.Rules | ForEach-Object {
                    @{
                        Name = $_.Name
                        Id = $_.Id
                        LastModified = $_.LastModified
                    }
                }
            }
        } else {
            $hashInput.AppliedState = $null
        }
        
        $hashJson = $hashInput | ConvertTo-Json -Depth 10 -Compress
        
        $stream = [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($hashJson))
        $hashResult = Get-FileHash -InputStream $stream -Algorithm SHA256
        return $hashResult.Hash
    }
    
    [string] GenerateConfigHash() {
        # Generate hash for configuration state only
        return $this.GenerateHash($false)
    }
    
    [hashtable] ToHashtable() {
        $result = @{
            Name = $this.Name
            Description = $this.Description
            Mode = $this.Mode
            Priority = $this.Priority
            Scope = $this.Scope
            Rules = $this.Rules | ForEach-Object { $_.ToHashtable() }
        }
        
        if ($this.Id) {
            $result.Id = $this.Id
        }
        
        if ($this.Hash) {
            $result.Hash = $this.Hash
        }
        
        if ($this.LastModified) {
            $result.LastModified = $this.LastModified.ToString('o')
        }
        
        return $result
    }
    
    <#
    .SYNOPSIS
        Converts the policy object to parameters for New-DlpCompliancePolicy or Set-DlpCompliancePolicy.
    .PARAMETER ForUpdate
        If $true, generates parameters for Set-DlpCompliancePolicy (update). If $false or omitted, generates for New-DlpCompliancePolicy (creation).
    #>
    [hashtable] ToIPPSPParameters([bool]$ForUpdate = $false) {
        $params = @{
            Name = $this.Name
            Comment = $this.Description
            Mode = $this.Mode
            Priority = $this.Priority
        }
        # Supported scopes and their parameter base names
        $scopeParamMap = @{
            exchange   = 'ExchangeLocation'
            sharepoint = 'SharePointLocation'
            onedrive   = 'OneDriveLocation'
            teams      = 'TeamsLocation'
            devices    = 'EndpointDlpLocation'
        }
        foreach ($scopeKey in $scopeParamMap.Keys) {
            # Set-DlpCompliancePolicy does not expose 'EndpointDlpLocation'; skip devices on update
            if ($ForUpdate -and $scopeKey -eq 'devices') { continue }
            $values = $this.Scope[$scopeKey]
            if ($null -ne $values -and $values.Count -gt 0) {
                $baseParam = $scopeParamMap[$scopeKey]
                $paramName = if ($ForUpdate) { "Add$baseParam" } else { $baseParam }
                $params[$paramName] = $values
            }
        }
        return $params
    }

    [hashtable] ToIPPSPParameters() {
        return $this.ToIPPSPParameters($false)
    }
    
    static [DLPaCPolicy] FromYaml([hashtable]$YamlObject) {
        $policy = [DLPaCPolicy]::new($YamlObject.name)
        
        if ($YamlObject.description) {
            $policy.Description = $YamlObject.description
        }
        
        if ($YamlObject.mode) {
            $policy.Mode = $YamlObject.mode
        }
        
        if ($YamlObject.priority) {
            $policy.Priority = $YamlObject.priority
        }
        
        if ($YamlObject.scope) {
            foreach ($key in $YamlObject.scope.Keys) {
                if ($policy.Scope.ContainsKey($key)) {
                    $val = $YamlObject.scope[$key]
                    # Accept both string ("All") and array
                    if ($val -is [string]) {
                        $policy.Scope[$key] = @($val)
                    } elseif ($val -is [System.Collections.IEnumerable] -and $val -isnot [string]) {
                        $policy.Scope[$key] = @($val)
                    } else {
                        $policy.Scope[$key] = @()
                    }
                }
            }
        }
        
        if ($YamlObject.rules) {
            foreach ($ruleObj in $YamlObject.rules) {
                $rule = [DLPaCRule]::FromYaml($ruleObj)
                $policy.AddRule($rule)
            }
        }
        
        $policy.UpdateHash()
        return $policy
    }
}