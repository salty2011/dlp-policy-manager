class DLPaCAction : DLPaCBaseObject {
    [string] $Type
    [bool] $NotifyUser
    [bool] $NotifyAdmin
    [string] $EncryptionMethod
    
    DLPaCAction() : base() {
        $this.NotifyUser = $false
        $this.NotifyAdmin = $false
    }
    
    DLPaCAction([string]$Type) : base() {
        $this.Type = $Type
        $this.NotifyUser = $false
        $this.NotifyAdmin = $false
    }
    
    [string] GenerateHash() {
        # Override base method for action-specific hash
        $hashInput = @{
            Type = $this.Type
            NotifyUser = $this.NotifyUser
            NotifyAdmin = $this.NotifyAdmin
            EncryptionMethod = $this.EncryptionMethod
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
        if ($this.NotifyUser) {
            $result.NotifyUser = $this.NotifyUser
        }
        
        if ($this.NotifyAdmin) {
            $result.NotifyAdmin = $this.NotifyAdmin
        }
        
        if ($this.EncryptionMethod) {
            $result.EncryptionMethod = $this.EncryptionMethod
        }
        
        return $result
    }
    
    [bool] Validate() {
        # Validate action based on its type
        switch ($this.Type) {
            "BlockAccess" {
                return $true  # No specific validation needed
            }
            "Encrypt" {
                return -not [string]::IsNullOrEmpty($this.EncryptionMethod)
            }
            default {
                return $false
            }
        }
        
        # Default return if switch doesn't handle it (should never reach here)
        return $false
    }
    
    static [DLPaCAction] FromYaml([hashtable]$YamlObject) {
        $action = [DLPaCAction]::new($YamlObject.type)
        
        if ($null -ne $YamlObject.notifyUser) {
            $action.NotifyUser = $YamlObject.notifyUser
        }
        
        if ($null -ne $YamlObject.notifyAdmin) {
            $action.NotifyAdmin = $YamlObject.notifyAdmin
        }
        
        if ($YamlObject.encryptionMethod) {
            $action.EncryptionMethod = $YamlObject.encryptionMethod
        }
        
        # Handle rmsTemplate mapping to EncryptionMethod for compatibility
        if ($YamlObject.rmsTemplate) {
            $action.EncryptionMethod = $YamlObject.rmsTemplate
        }
        
        $action.UpdateHash()
        return $action
    }
}