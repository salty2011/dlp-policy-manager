# Script to diagnose and fix plan file issues
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$PlanPath
)

# Helper function to convert PSCustomObject to hashtable recursively
function ConvertTo-Hashtable {
    param (
        [Parameter(ValueFromPipeline)]
        $InputObject
    )
    
    process {
        if ($null -eq $InputObject) {
            return $null
        }
        
        if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
            $hash = @{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $hash[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
            }
            return $hash
        }
        elseif ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $array = @()
            foreach ($object in $InputObject) {
                $array += ConvertTo-Hashtable -InputObject $object
            }
            return $array
        }
        else {
            return $InputObject
        }
    }
}

# Read the plan file
Write-Host "Reading plan file: $PlanPath"
$planJson = Get-Content -Path $PlanPath -Raw
$planObject = $planJson | ConvertFrom-Json

# Display diagnostic information
Write-Host "`nDiagnostic Information:"
Write-Host "----------------------"
Write-Host "Metadata type: $($planObject.metadata.GetType().FullName)"
Write-Host "Metadata content: $($planObject.metadata | ConvertTo-Json -Compress)"

# Convert PSCustomObjects to hashtables
Write-Host "`nConverting PSCustomObjects to hashtables..."
$fixedPlanObject = @{
    metadata = ConvertTo-Hashtable -InputObject $planObject.metadata
    createdAt = $planObject.createdAt
    changes = $planObject.changes | ForEach-Object {
        @{
            operation = $_.operation
            resourceType = $_.resourceType
            resourceName = $_.resourceName
            parentResource = $_.parentResource
            oldState = ConvertTo-Hashtable -InputObject $_.oldState
            newState = ConvertTo-Hashtable -InputObject $_.newState
            changeReason = $_.changeReason
        }
    }
}

# Create a backup of the original file
$backupPath = "$PlanPath.bak"
Write-Host "Creating backup of original file: $backupPath"
Copy-Item -Path $PlanPath -Destination $backupPath -Force

# Save the fixed plan file
Write-Host "Saving fixed plan file: $PlanPath"
$fixedPlanJson = $fixedPlanObject | ConvertTo-Json -Depth 10
$fixedPlanJson | Out-File -FilePath $PlanPath -Encoding utf8 -Force

Write-Host "`nPlan file fixed successfully!"
Write-Host "You can now try running your original command again."