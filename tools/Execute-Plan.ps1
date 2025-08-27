# Script to directly execute a plan file without using the DLPaCPlan class
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$PlanPath
)
Import-Module ./DLPaC/DLPaC.psm1 -force
# Load the plan file
Write-Host "Loading plan from $PlanPath"
$planJson = Get-Content -Path $PlanPath -Raw
$planObject = $planJson | ConvertFrom-Json

# Display plan summary
$createCount = ($planObject.changes | Where-Object { $_.operation -eq "Create" }).Count
$updateCount = ($planObject.changes | Where-Object { $_.operation -eq "Update" }).Count
$deleteCount = ($planObject.changes | Where-Object { $_.operation -eq "Delete" }).Count
$totalCount = $planObject.changes.Count

Write-Host "Plan: $totalCount changes"
Write-Host ""
Write-Host "  Create: $createCount"
Write-Host "  Update: $updateCount"
Write-Host "  Delete: $deleteCount"
Write-Host ""
Write-Host "Changes:"

foreach ($change in $planObject.changes) {
    $changeDesc = "  + $($change.operation) $($change.resourceType): $($change.resourceName)"
    if ($change.parentResource) {
        $changeDesc += " (in $($change.parentResource))"
    }
    if ($change.changeReason) {
        $changeDesc += " - $($change.changeReason)"
    }
    Write-Host $changeDesc
}

# Confirm application
$confirmation = Read-Host "Do you want to apply these changes? (y/n)"
if ($confirmation -ne "y") {
    Write-Host "Plan application cancelled."
    return
}

# Initialize workspace
Write-Host "Initializing workspace..."
Import-Module ./DLPaC/DLPaC.psd1 -Force
Initialize-DLPaCWorkspace -Path ./Test -TenantName 'Test' -Environment 'Dev' -Force

# Apply the plan using the original Invoke-DLPaCApply function
Write-Host "Applying plan..."
Invoke-DLPaCApply -PlanPath $PlanPath -AutoApprove