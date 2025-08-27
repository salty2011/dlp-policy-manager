class DLPaCCondition : DLPaCBaseObject {
    [string] $Type
    [string] $Pattern
    [string] $InfoType
    [int] $MinCount = 1
    [string] $Operator
    [string] $Value
    
    DLPaCCondition() : base() {
        $this.MinCount = 1
    }
    
    DLPaCCondition([string]$Type) : base() {
        $this.Type = $Type
        $this.MinCount = 1
    }
    
    [string] GenerateHash() {
        # Override base method for condition-specific hash
        $hashInput = @{
            Type = $this.Type
            Pattern = $this.Pattern
            InfoType = $this.InfoType
            MinCount = $this.MinCount
            Operator = $this.Operator
            Value = $this.Value
        } | ConvertTo-Json -Depth 10 -Compress
        
        $stream = [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($hashInput))
        $hashResult = Get-FileHash -InputStream $stream -Algorithm SHA256
        return $hashResult.Hash
    }
    
    [hashtable] ToHashtable() {
        $result = @{
            Type = $this.Type
        }
        
        # Only include properties that are set
        if ($this.Pattern) {
            $result.Pattern = $this.Pattern
        }
        
        if ($this.InfoType) {
            $result.InfoType = $this.InfoType
        }
        
        if ($this.MinCount -gt 0) {
            $result.MinCount = $this.MinCount
        }
        
        if ($this.Operator) {
            $result.Operator = $this.Operator
        }
        
        if ($this.Value) {
            $result.Value = $this.Value
        }
        
        return $result
    }
    
    [bool] Validate() {
        # Validate condition based on its type
        switch ($this.Type) {
            "ContentContainsPattern" {
                return -not [string]::IsNullOrEmpty($this.Pattern)
            }
            "SensitiveInfoType" {
                return -not [string]::IsNullOrEmpty($this.InfoType)
            }
            "RecipientDomain" {
                return -not [string]::IsNullOrEmpty($this.Operator) -and -not [string]::IsNullOrEmpty($this.Value)
            }
            "AccessScope" {
                return -not [string]::IsNullOrEmpty($this.Value)
            }
            default {
                return $false
            }
        }
        
        # Default return if switch doesn't handle it (should never reach here)
        return $false
    }
    
    static [DLPaCCondition] FromYaml([hashtable]$YamlObject) {
        $condition = [DLPaCCondition]::new($YamlObject.type)
        
        if ($YamlObject.pattern) {
            $condition.Pattern = $YamlObject.pattern
        }
        
        if ($YamlObject.infoType) {
            $condition.InfoType = $YamlObject.infoType
        }
        
        if ($YamlObject.minCount) {
            $condition.MinCount = $YamlObject.minCount
        }
        
        if ($YamlObject.operator) {
            $condition.Operator = $YamlObject.operator
        }
        
        if ($YamlObject.value) {
            $condition.Value = $YamlObject.value
        }
        
        $condition.UpdateHash()
        return $condition
    }
}