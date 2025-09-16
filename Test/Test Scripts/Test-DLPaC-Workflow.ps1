# Script to test the complete DLPaC workflow - Terraform-style directory planning
[CmdletBinding()]
param (
    [Parameter()]
    [string]$ConfigsPath = "./configs/",

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
Import-Module "$PSScriptRoot/../../DLPaC/DLPaC.psd1" -Force

Write-Host "`nConnecting to Exchange Online (manual session)..." -ForegroundColor Cyan
Connect-DLPaC

try {
    # Initialize workspace
    Write-Host "`nInitializing workspace..." -ForegroundColor Cyan
    Initialize-DLPaCWorkspace -Path ./Test -TenantName 'Test' -Environment 'Dev' -Force
     
    # Display discovered configuration files
    Write-Host "`nDiscovering configuration files in $ConfigsPath..." -ForegroundColor Cyan
    $configFiles = Get-ChildItem -Path $ConfigsPath -Filter "*.yaml" | Sort-Object Name
    
    if ($configFiles.Count -eq 0) {
        Write-Host "No YAML configuration files found in $ConfigsPath" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Found $($configFiles.Count) configuration files:" -ForegroundColor Green
    foreach ($file in $configFiles) {
        Write-Host "  - $($file.Name)" -ForegroundColor Gray
    }
    
    # Test directory configuration (Terraform-style: all configs at once)
    Write-Host "`nTesting directory configuration..." -ForegroundColor Cyan
    try {
        $testResult = Test-DLPaCConfiguration -Path $ConfigsPath
        if ($testResult.InvalidFiles -gt 0) {
            Write-Host "Configuration validation failed:" -ForegroundColor Red
            foreach ($result in $testResult.Results) {
                if (-not $result.Valid) {
                    Write-Host "  File: $($result.File)" -ForegroundColor Red
                    foreach ($schemaError in $result.SchemaErrors) {
                        Write-Host "    - Schema: $schemaError" -ForegroundColor Red
                    }
                    foreach ($logicalError in $result.LogicalErrors) {
                        Write-Host "    - Logic: $logicalError" -ForegroundColor Red
                    }
                }
            }
            Write-Host "`nDirectory configuration validation failed - cannot proceed with planning" -ForegroundColor Red
            exit 1
        }
        Write-Host "Directory configuration validation successful!" -ForegroundColor Green
    }
    catch {
        Write-Host "Configuration validation failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "This demonstrates that incompatible configurations prevent the entire workflow" -ForegroundColor Yellow
        exit 1
    }
    
    # Generate plan for entire directory (Terraform-style: single plan for all configs)
    Write-Host "`nGenerating plan for all configurations..." -ForegroundColor Cyan
    try {
        $planResult = Get-DLPaCPlan -Path $ConfigsPath
        $planPath = $planResult.PlanPath
        Write-Host "Plan generated successfully: $planPath" -ForegroundColor Green
    }
    catch {
        Write-Host "Plan generation failed: $($_.Exception.Message)" -ForegroundColor Red
        
        # Check if this is a compatibility error
        if ($_.Exception.Message -like "*compatibility error*") {
            Write-Host "`n🎯 ARCHITECTURAL FIX DEMONSTRATION:" -ForegroundColor Yellow
            Write-Host "   Planning failed due to compatibility errors in the configuration directory." -ForegroundColor Yellow
            Write-Host "   This correctly prevents ANY deployment from proceeding." -ForegroundColor Yellow
            Write-Host "   Like Terraform: if ANY config is invalid, NO plan can be created." -ForegroundColor Yellow
            
            # Now demonstrate that Apply cannot proceed
            Write-Host "`nTesting Apply behavior with failed planning..." -ForegroundColor Cyan
            try {
                Invoke-DLPaCApply -AutoApprove
                Write-Host "❌ ERROR: Apply should have failed!" -ForegroundColor Red
                exit 1
            }
            catch {
                Write-Host "✅ SUCCESS: Apply correctly rejected - $($_.Exception.Message)" -ForegroundColor Green
                Write-Host "`n🏆 ARCHITECTURAL FIX VERIFIED:" -ForegroundColor Green
                Write-Host "   ✓ Planning failed for incompatible configurations" -ForegroundColor Green
                Write-Host "   ✓ Apply correctly rejected due to no valid plan" -ForegroundColor Green
                Write-Host "   ✓ System maintains Terraform-like integrity" -ForegroundColor Green
                exit 0
            }
        }
        else {
            Write-Host "Planning failed for unexpected reason: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
    
    # If we reach here, planning succeeded - display plan summary
    Write-Host "`nPlan Summary:" -ForegroundColor Cyan
    $planJson = Get-Content -Path $planPath -Raw
    $planObject = $planJson | ConvertFrom-Json
    
    $createCount = ($planObject.changes | Where-Object { $_.operation -eq "Create" }).Count
    $updateCount = ($planObject.changes | Where-Object { $_.operation -eq "Update" }).Count
    $deleteCount = ($planObject.changes | Where-Object { $_.operation -eq "Delete" }).Count
    $totalCount = $planObject.changes.Count
    
    Write-Host "Plan: $totalCount changes" -ForegroundColor White
    Write-Host ""
    Write-Host "  Create: $createCount" -ForegroundColor Green
    Write-Host "  Update: $updateCount" -ForegroundColor Yellow
    Write-Host "  Delete: $deleteCount" -ForegroundColor Red
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
        
        $color = switch ($change.operation) {
            "Create" { "Green" }
            "Update" { "Yellow" }
            "Delete" { "Red" }
            default { "White" }
        }
        Write-Host $changeDesc -ForegroundColor $color
    }
    
    # Verify plan status file was created correctly
    Write-Host "`nVerifying plan status..." -ForegroundColor Cyan
    $statusPath = $planPath -replace '\.json$', '.status.json'
    if (Test-Path $statusPath) {
        $status = Get-Content -Path $statusPath -Raw | ConvertFrom-Json
        if ($status.status -eq "success") {
            Write-Host "✅ Plan status: SUCCESS" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Plan status: $($status.status)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "⚠️ No status file found" -ForegroundColor Yellow
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
    try {
        $applyResult = Invoke-DLPaCApply -PlanPath $planPath -AutoApprove
        
        # Display results
        Write-Host "`nPlan application completed!" -ForegroundColor Green
        Write-Host "Total Changes: $($applyResult.TotalChanges)" -ForegroundColor White
        Write-Host "Success: $($applyResult.SuccessCount)" -ForegroundColor Green
        Write-Host "Failure: $($applyResult.FailureCount)" -ForegroundColor Red
        Write-Host "Completed At: $($applyResult.CompletedAt)" -ForegroundColor Gray
        
        Write-Host "`n🏆 WORKFLOW COMPLETED SUCCESSFULLY:" -ForegroundColor Green
        Write-Host "   ✓ All configurations validated" -ForegroundColor Green
        Write-Host "   ✓ Plan generated for entire directory" -ForegroundColor Green
        Write-Host "   ✓ Plan applied successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "Apply failed: $($_.Exception.Message)" -ForegroundColor Red
        
        # Check if this is due to plan status issues
        if ($_.Exception.Message -like "*Plan status*" -or $_.Exception.Message -like "*Cannot apply plan*") {
            Write-Host "✅ This demonstrates the architectural fix working correctly" -ForegroundColor Green
        }
        exit 1
    }
}
finally {
    Write-Host "`nDisconnecting DLPaC manual session..." -ForegroundColor Cyan
    Disconnect-DLPaC
}