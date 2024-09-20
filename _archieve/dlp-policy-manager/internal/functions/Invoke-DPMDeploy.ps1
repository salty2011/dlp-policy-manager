<#
# TODO: Create deployment logic
Order should be
1. Classifiers
2. Labels
3. Policies
4. Rules
#>
Write-Output "Starting deployment process..."

# Deploy policies if not empty
if ($policies.Count -gt 0) {
    Write-Output "Deploying policies..."
    Deploy-DPMPolicies -policies $policies
} else {
    Write-Output "No policies to deploy."
}

Write-Output "Deployment process completed."