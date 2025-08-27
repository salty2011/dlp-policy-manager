class DLPaCBaseObject {
    [string] $Name
    [string] $Id
    [string] $Hash
    [datetime] $LastModified
    
    DLPaCBaseObject() {
        $this.LastModified = Get-Date
    }
    
    DLPaCBaseObject([string]$Name) {
        $this.Name = $Name
        $this.LastModified = Get-Date
    }
    
    [string] GenerateHash() {
        # Default implementation - override in derived classes
        $hashInput = $this | ConvertTo-Json -Depth 10 -Compress
        $stream = [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($hashInput))
        $hashResult = Get-FileHash -InputStream $stream -Algorithm SHA256
        return $hashResult.Hash
    }
    
    [void] UpdateHash() {
        $this.Hash = $this.GenerateHash()
    }
    
    [hashtable] ToHashtable() {
        # Convert object to hashtable for serialization
        $properties = $this.GetType().GetProperties() | Where-Object { $_.Name -ne "Hash" -and $_.Name -ne "LastModified" }
        $hashtable = @{}
        
        foreach ($property in $properties) {
            $value = $this.$($property.Name)
            if ($null -ne $value) {
                $hashtable[$property.Name] = $value
            }
        }
        
        return $hashtable
    }
    
    [string] ToString() {
        return "$($this.GetType().Name): $($this.Name)"
    }
}