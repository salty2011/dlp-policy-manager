# Script to test schema validation directly
param(
    [Parameter(Mandatory=$true)]
    [string]$YamlFilePath,
    
    [Parameter(Mandatory=$true)]
    [string]$SchemaPath
)

# Import the powershell-yaml module
Import-Module powershell-yaml

# Read the YAML file
$yamlContent = Get-Content -Path $YamlFilePath -Raw
Write-Host "Read YAML file: $YamlFilePath"

# Read the schema file
$schemaContent = Get-Content -Path $SchemaPath -Raw
Write-Host "Read schema file: $SchemaPath"

# Try to parse the YAML
try {
    $yamlObject = $yamlContent | ConvertFrom-Yaml
    Write-Host "Successfully parsed YAML"
    
    # Try to parse the schema
    $schemaObject = $schemaContent | ConvertFrom-Json -AsHashtable
    Write-Host "Successfully parsed schema"
    
    # Define a function to validate an object against a schema
    function Test-ObjectAgainstSchema {
        param(
            [Parameter(Mandatory=$true)]
            [object]$Object,
            
            [Parameter(Mandatory=$true)]
            [hashtable]$Schema,
            
            [string]$Path = ""
        )
        
        $errors = @()
        
        # Check type
        if ($Schema.type) {
            $typeValid = $false
            
            switch ($Schema.type) {
                "string" { $typeValid = $Object -is [string] }
                "number" { $typeValid = $Object -is [int] -or $Object -is [long] -or $Object -is [double] }
                "integer" { $typeValid = $Object -is [int] -or $Object -is [long] }
                "boolean" { $typeValid = $Object -is [bool] }
                "array" { $typeValid = $Object -is [array] -or $Object -is [System.Collections.ArrayList] }
                "object" { $typeValid = $Object -is [hashtable] -or $Object -is [System.Collections.Specialized.OrderedDictionary] }
                default { $typeValid = $true }
            }
            
            if (-not $typeValid) {
                $errors += "Property '$Path' should be of type '$($Schema.type)' but got '$($Object.GetType().Name)'"
            }
        }
        
        # Check required properties
        if ($Schema.required -and $Schema.properties -and $Object -is [hashtable]) {
            foreach ($requiredProp in $Schema.required) {
                if (-not $Object.ContainsKey($requiredProp)) {
                    $errors += "Required property '$requiredProp' is missing at '$Path'"
                }
            }
        }
        
        # Check enum values
        if ($Schema.enum -and -not $Schema.enum.Contains($Object)) {
            $errors += "Property '$Path' value '$Object' is not one of the allowed values: $($Schema.enum -join ', ')"
        }
        
        # Check properties
        if ($Schema.properties -and $Object -is [hashtable]) {
            foreach ($propName in $Object.Keys) {
                $propPath = if ($Path) { "$Path.$propName" } else { $propName }
                $propValue = $Object[$propName]
                
                if ($Schema.properties.ContainsKey($propName)) {
                    $propSchema = $Schema.properties[$propName]
                    $propErrors = Test-ObjectAgainstSchema -Object $propValue -Schema $propSchema -Path $propPath
                    $errors += $propErrors
                }
                elseif (-not $Schema.additionalProperties) {
                    $errors += "Property '$propPath' is not defined in the schema"
                }
            }
        }
        
        # Check array items
        if ($Schema.items -and $Object -is [array]) {
            for ($i = 0; $i -lt $Object.Count; $i++) {
                $itemPath = "$Path[$i]"
                $itemErrors = Test-ObjectAgainstSchema -Object $Object[$i] -Schema $Schema.items -Path $itemPath
                $errors += $itemErrors
            }
        }
        
        # Check conditional validation (allOf)
        if ($Schema.allOf -and $Object -is [hashtable]) {
            foreach ($condition in $Schema.allOf) {
                if ($condition.if -and $condition.then) {
                    $ifSchema = $condition.if
                    $thenSchema = $condition.then
                    
                    # Check if the if condition matches
                    $ifMatches = $true
                    
                    if ($ifSchema.properties) {
                        foreach ($propName in $ifSchema.properties.Keys) {
                            if ($Object.ContainsKey($propName)) {
                                $propValue = $Object[$propName]
                                $propSchema = $ifSchema.properties[$propName]
                                
                                if ($propSchema.enum -and -not $propSchema.enum.Contains($propValue)) {
                                    $ifMatches = $false
                                    break
                                }
                            }
                        }
                    }
                    
                    # If the if condition matches, apply the then schema
                    if ($ifMatches) {
                        if ($thenSchema.required) {
                            foreach ($requiredProp in $thenSchema.required) {
                                if (-not $Object.ContainsKey($requiredProp)) {
                                    $errors += "Required property '$requiredProp' is missing at '$Path' (required by conditional validation)"
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return $errors
    }
    
    # Validate the YAML object against the schema
    $validationErrors = Test-ObjectAgainstSchema -Object $yamlObject -Schema $schemaObject
    
    if ($validationErrors.Count -eq 0) {
        Write-Host "Validation successful! No errors found." -ForegroundColor Green
    } else {
        Write-Host "Validation failed with $($validationErrors.Count) errors:" -ForegroundColor Red
        foreach ($error in $validationErrors) {
            Write-Host "  - $error" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}