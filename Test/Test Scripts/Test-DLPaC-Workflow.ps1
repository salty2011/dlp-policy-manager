# Script to test the complete DLPaC workflow
[CmdletBinding()]
param (
    [Parameter()]
    [string]$ConfigPath = "../Test/configs/example-policy.yaml",

    [Parameter()]
    [switch]$AutoApprove
)

# Ensure the module is properly unloaded before reloading
if (Get-Module DLPaC) {
    Write-Host "Removing existing DLPaC module..." -ForegroundColor Yellow
    Remove-Module DLPaC -Force
}

# Import the module
Write-Host "Importing DLPaC module..." -ForegroundColor Cyan
Import-Module ../../DLPaC/DLPaC.psd1 -Force

Write-Host "`nConnecting to Exchange Online (manual session)..." -ForegroundColor Cyan
Connect-DLPaC

try {
# Initialize workspace
Write-Host "`nInitializing workspace..." -ForegroundColor Cyan
Initialize-DLPaCWorkspace -Path ../Test -TenantName 'Test' -Environment 'Dev' -Force
 
# Test configuration
Write-Host "`nTesting configuration..." -ForegroundColor Cyan
$testResult = Test-DLPaCConfiguration -Path $ConfigPath
if ($testResult.InvalidFiles -gt 0) {
    Write-Host "Configuration validation failed:" -ForegroundColor Red
    foreach ($result in $testResult.Results) {
        if (-not $result.Valid) {
            foreach ($schemaError in $result.SchemaErrors) {
                Write-Host "  - $schemaError" -ForegroundColor Red
            }
            foreach ($logicalError in $result.LogicalErrors) {
                Write-Host "  - $logicalError" -ForegroundColor Red
            }
        }
    }
    exit 1
}
Write-Host "Configuration validation successful!" -ForegroundColor Green

# Generate plan
Write-Host "`nGenerating plan..." -ForegroundColor Cyan
$planResult = Get-DLPaCPlan -Path $ConfigPath
$planPath = $planResult.PlanPath
Write-Host "Plan generated: $planPath" -ForegroundColor Green

# Display plan summary
Write-Host "`nPlan Summary:" -ForegroundColor Cyan
$planJson = Get-Content -Path $planPath -Raw
$planObject = $planJson | ConvertFrom-Json

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
if (-not $AutoApprove) {
    $confirmation = Read-Host "`nDo you want to apply these changes? (y/n)"
    if ($confirmation -ne "y") {
        Write-Host "Plan application cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Apply the plan
Write-Host "`nApplying plan..." -ForegroundColor Cyan
$applyResult = Invoke-DLPaCApply -PlanPath $planPath -AutoApprove
 
# Display results
Write-Host "`nPlan application completed!" -ForegroundColor Green
Write-Host "Total Changes: $($applyResult.TotalChanges)"
Write-Host "Success: $($applyResult.SuccessCount)"
Write-Host "Failure: $($applyResult.FailureCount)"
Write-Host "Completed At: $($applyResult.CompletedAt)"
}
finally {
    Write-Host "`nDisconnecting DLPaC manual session..." -ForegroundColor Cyan
    Disconnect-DLPaC
}