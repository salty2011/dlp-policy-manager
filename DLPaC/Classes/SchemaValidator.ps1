class DLPaCSchemaValidator {
    [string] $SchemaPath
    [hashtable] $Schema
    
    DLPaCSchemaValidator() {
    }
    
    DLPaCSchemaValidator([string]$SchemaPath) {
        $this.SchemaPath = $SchemaPath
        $this.LoadSchema()
    }
    
    [void] LoadSchema() {
        if (-not $this.SchemaPath -or -not (Test-Path $this.SchemaPath)) {
            throw "Schema file not found: $($this.SchemaPath)"
        }
        
        try {
            $schemaJson = Get-Content -Path $this.SchemaPath -Raw
            $this.Schema = $schemaJson | ConvertFrom-Json -AsHashtable
        }
        catch {
            throw "Failed to load schema file: $_"
        }
    }
    
    [bool] ValidateYaml([hashtable]$YamlObject) {
        $errors = @()
        
        # Log the top-level keys in the YAML object
        Write-Host "Validating YAML object with keys: $($YamlObject.Keys -join ', ')"
        
        # Check if 'policies' key exists and log its type
        if ($YamlObject.ContainsKey('policies')) {
            Write-Host "Found 'policies' key with type: $($YamlObject.policies.GetType().FullName)"
            if ($YamlObject.policies -is [array]) {
                Write-Host "Policies is an array with $($YamlObject.policies.Count) items"
            }
        } else {
            Write-Host "ERROR: 'policies' key not found in YAML object"
        }
        
        $this.ValidateObject($YamlObject, $this.Schema, "", [ref]$errors)
        
        if ($errors.Count -gt 0) {
            Write-Host "Schema validation found $($errors.Count) errors:"
            foreach ($error in $errors) {
                Write-Error $error
                Write-Host "ERROR: $error" -ForegroundColor Red
            }
            return $false
        }
        
        Write-Host "Schema validation successful" -ForegroundColor Green
        return $true
    }
    
    [void] ValidateObject([object]$Object, [hashtable]$Schema, [string]$Path, [ref]$Errors) {
        # Check type
        if ($Schema.type -and -not $this.ValidateType($Object, $Schema.type)) {
            $Errors.Value += "Property '$Path' should be of type '$($Schema.type)' but got '$($Object.GetType().Name)'"
            return
        }
        
        # Check required properties
        if ($Schema.required -and $Schema.properties) {
            foreach ($requiredProp in $Schema.required) {
                # Skip 'actions' if it's not required in the schema (for backward compatibility)
                if ($requiredProp -eq 'actions') { continue }
                if (-not $Object.ContainsKey($requiredProp)) {
                    $Errors.Value += "Required property '$requiredProp' is missing at '$Path'"
                }
            }
        }
        
        # Check enum values
        if ($Schema.enum -and -not $Schema.enum.Contains($Object)) {
            $Errors.Value += "Property '$Path' value '$Object' is not one of the allowed values: $($Schema.enum -join ', ')"
            return
        }
        
        # Check properties
        if ($Schema.properties -and $Object -is [hashtable]) {
            foreach ($propName in $Object.Keys) {
                $propPath = if ($Path) { "$Path.$propName" } else { $propName }
                $propValue = $Object[$propName]
                
                if ($Schema.properties.ContainsKey($propName)) {
                    $propSchema = $Schema.properties[$propName]
                    $this.ValidateObject($propValue, $propSchema, $propPath, $Errors)
                }
                elseif (-not $Schema.additionalProperties) {
                    $Errors.Value += "Property '$propPath' is not defined in the schema"
                }
            }
        }
        
        # Check array items
        if ($Schema.items -and $Object -is [array]) {
            for ($i = 0; $i -lt $Object.Count; $i++) {
                $itemPath = "$Path[$i]"
                $this.ValidateObject($Object[$i], $Schema.items, $itemPath, $Errors)
            }
        }
        
        # Check minimum/maximum for numbers
        if ($Object -is [int] -or $Object -is [long] -or $Object -is [double]) {
            if ($null -ne $Schema.minimum -and $Object -lt $Schema.minimum) {
                $Errors.Value += "Property '$Path' value '$Object' is less than minimum allowed value '$($Schema.minimum)'"
            }
            
            if ($null -ne $Schema.maximum -and $Object -gt $Schema.maximum) {
                $Errors.Value += "Property '$Path' value '$Object' is greater than maximum allowed value '$($Schema.maximum)'"
            }
        }
        
        # Check minLength/maxLength for strings
        if ($Object -is [string]) {
            if ($null -ne $Schema.minLength -and $Object.Length -lt $Schema.minLength) {
                $Errors.Value += "Property '$Path' length '$($Object.Length)' is less than minimum allowed length '$($Schema.minLength)'"
            }
            
            if ($null -ne $Schema.maxLength -and $Object.Length -gt $Schema.maxLength) {
                $Errors.Value += "Property '$Path' length '$($Object.Length)' is greater than maximum allowed length '$($Schema.maxLength)'"
            }
            
            # Check pattern
            if ($null -ne $Schema.pattern -and $Object -notmatch $Schema.pattern) {
                $Errors.Value += "Property '$Path' value '$Object' does not match pattern '$($Schema.pattern)'"
            }
        }
    }
    
    [bool] ValidateType([object]$Value, [string]$Type) {
        switch ($Type) {
            "string" { return $Value -is [string] }
            "number" { return $Value -is [int] -or $Value -is [long] -or $Value -is [double] }
            "integer" { return $Value -is [int] -or $Value -is [long] }
            "boolean" { return $Value -is [bool] }
            "array" {
                return (
                    $Value -is [array] -or
                    $Value -is [System.Collections.ArrayList] -or
                    ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string])
                )
            }
            "object" { return $Value -is [hashtable] -or $Value -is [System.Collections.Specialized.OrderedDictionary] }
            default { return $true }
        }
        
        # Default return if switch doesn't handle it (should never reach here)
        return $false
    }
}