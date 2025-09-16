function Invoke-DLPaCDestroy {
    <#
    .SYNOPSIS
        Removes DLP policies from the Microsoft 365 tenant.
    
    .DESCRIPTION
        The Invoke-DLPaCDestroy function removes DLP policies from the Microsoft 365 tenant
        that were created or managed by DLPaC. It can remove specific policies or all policies
        in the current state.
    
    .PARAMETER PolicyName
        The name of the specific policy to remove. If not specified, all policies in the current
        state will be removed.
    
    .PARAMETER AutoApprove
        If specified, removes the policies without prompting for confirmation.
    
    .PARAMETER WhatIf
        If specified, shows what policies would be removed without actually removing them.
    
    .EXAMPLE
        Invoke-DLPaCDestroy
        
        Removes all DLP policies in the current state after prompting for confirmation.
    
    .EXAMPLE
        Invoke-DLPaCDestroy -PolicyName "Financial Data Protection" -AutoApprove
        
        Removes the specified DLP policy without prompting for confirmation.
    
    .NOTES
        This function requires an initialized DLPaC workspace and appropriate permissions to
        remove DLP policies in the Microsoft 365 tenant.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Position = 0)]
        [string]$PolicyName,
        
        [Parameter()]
        [switch]$AutoApprove
    )
    
    begin {
        # Initialize logger
        if (-not $script:Logger) {
            $script:Logger = [DLPaCLogger]::new()
        }
        
        $script:Logger.LogInfo("Starting policy destruction")
        
        # Validate workspace is initialized
        if (-not $script:WorkspacePath) {
            $errorMessage = "DLPaC workspace not initialized. Run Initialize-DLPaCWorkspace first."
            $script:Logger.LogError($errorMessage)
            throw $errorMessage
        }
        
        # Initialize IPPSP adapter (reuse cached adapter when manual session active)
        if ($script:IPPSPAdapter) {
            $ippspAdapter = $script:IPPSPAdapter
        }
        else {
            $ippspAdapter = [DLPaCIPPSPAdapter]::new($script:Logger)
        }
    }
    
    process {
        try {
            # Load state
            $statePath = $script:StatePath
            if (-not $statePath) {
                $statePath = Join-Path $script:WorkspacePath ".dlpac\state\dlpac.state.json"
            }
            
            $script:Logger.LogInfo("Loading state from $statePath")
            $state = [DLPaCState]::Load($statePath)
            
            # Determine policies to remove
            $policiesToRemove = @()
            
            if ($PolicyName) {
                if ($state.Policies.ContainsKey($PolicyName)) {
                    $policiesToRemove += $PolicyName
                }
                else {
                    $errorMessage = "Policy '$PolicyName' not found in state"
                    $script:Logger.LogError($errorMessage)
                    throw $errorMessage
                }
            }
            else {
                $policiesToRemove = $state.Policies.Keys
            }
            
            $policyCount = $policiesToRemove.Count
            
            if ($policyCount -eq 0) {
                $script:Logger.LogInfo("No policies to remove")
                Write-Host "No policies to remove."
                return
            }
            
            # Display policies to remove
            Write-Host "The following policies will be removed:"
            foreach ($policy in $policiesToRemove) {
                Write-Host "  - $policy"
            }
            
            # Confirm removal
            if (-not $AutoApprove -and -not $WhatIfPreference) {
                $confirmation = Read-Host "Do you want to remove these policies? This action cannot be undone. (y/n)"
                
                if ($confirmation -ne "y") {
                    $script:Logger.LogInfo("Policy destruction cancelled by user")
                    Write-Host "Policy destruction cancelled."
                    return
                }
            }
            
            # Connect to Exchange Online
            $script:Logger.LogInfo("Connecting to Exchange Online")
            $connected = $ippspAdapter.Connect()
            
            if (-not $connected) {
                $errorMessage = "Failed to connect to Exchange Online"
                $script:Logger.LogError($errorMessage)
                throw $errorMessage
            }
            
            # Lock state file
            $script:Logger.LogInfo("Locking state file")
            $state.Lock()
            
            # Remove policies
            $currentPolicy = 0
            $successCount = 0
            $failureCount = 0
            
            foreach ($policy in $policiesToRemove) {
                $currentPolicy++
                $progressPercent = [math]::Round(($currentPolicy / $policyCount) * 100)
                
                Write-Progress -Activity "Removing policies" -Status "$currentPolicy of $policyCount" -PercentComplete $progressPercent
                
                $script:Logger.LogInfo("Removing policy: $policy")
                
                try {
                    if ($PSCmdlet.ShouldProcess($policy, "Remove DLP Policy")) {
                        $ippspAdapter.DeletePolicy($policy)
                        $state.RemovePolicy($policy)
                        $successCount++
                    }
                }
                catch {
                    $script:Logger.LogError("Failed to remove policy: $policy. Error: $_")
                    $failureCount++
                }
            }
            
            Write-Progress -Activity "Removing policies" -Completed
            
            # Save state
            $script:Logger.LogInfo("Saving state")
            $state.Save()
            
            # Unlock state file
            $script:Logger.LogInfo("Unlocking state file")
            $state.Unlock()
            
            # Display results
            $script:Logger.LogInfo("Policy destruction completed. Success: $successCount, Failure: $failureCount")
            
            [PSCustomObject]@{
                TotalPolicies = $policyCount
                SuccessCount = $successCount
                FailureCount = $failureCount
                CompletedAt = Get-Date
            }
        }
        catch {
            $script:Logger.LogError("Error removing policies: $_")
            throw $_
        }
        finally {
            # Unlock state file if locked
            if ($state -and $state.IsLocked) {
                $script:Logger.LogInfo("Unlocking state file")
                $state.Unlock()
            }
            
            # Disconnect from Exchange Online only when not in a manual session
            if (-not $script:ManualSessionActive -and $ippspAdapter.IsConnected) {
                $script:Logger.LogInfo("Disconnecting from Exchange Online")
                $ippspAdapter.Disconnect()
            }
        }
    }
}