Write-Output "Starting deployment process..."
# Deploy classifiers if not empty
<# if ($classifiers.Count -gt 0) {
    Write-Output "Deploying classifiers..."
    Deploy-DPMClassifiers -classifiers $classifiers
} else {
    Write-Output "No classifiers to deploy."
} #>

# Deploy policies if not empty
if ($policies.Count -gt 0) {
    Write-Output "Deploying policies..."
    Deploy-DPMPolicies -policies $policies
} else {
    Write-Output "No policies to deploy."
}

<# # Deploy rules if not empty
if ($rules.Count -gt 0) {
    Write-Output "Deploying rules..."
    Deploy-DPMRules -rules $rules
} else {
    Write-Output "No rules to deploy."
} #>

Write-Output "Deployment process completed."