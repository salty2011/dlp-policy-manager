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
class DLPaCPlanItem {
    [string] $Operation  # Create, Update, Delete
    [string] $ResourceType  # Policy, Rule
    [string] $ResourceName
    [string] $ParentResource
    [PSCustomObject] $OldState
    [PSCustomObject] $NewState
    [string] $ChangeReason
    
    DLPaCPlanItem() {
    }
    
    DLPaCPlanItem([string]$Operation, [string]$ResourceType, [string]$ResourceName) {
        $this.Operation = $Operation
        $this.ResourceType = $ResourceType
        $this.ResourceName = $ResourceName
    }
    
    [string] ToString() {
        $output = "$($this.Operation) $($this.ResourceType): $($this.ResourceName)"
        
        if ($this.ParentResource) {
            $output += " (in $($this.ParentResource))"
        }
        
        if ($this.ChangeReason) {
            $output += " - $($this.ChangeReason)"
        }
        
        return $output
    }
}

class DLPaCPlan {
    [System.Collections.ArrayList] $Changes
    [string] $PlanPath
    [datetime] $CreatedAt
    [datetime] $CacheTimestamp
    [bool] $UsedCacheState
    [System.Collections.Hashtable] $Metadata
    
    DLPaCPlan() {
        $this.Changes = [System.Collections.ArrayList]::new()
        $this.CreatedAt = [datetime]::UtcNow
        $this.CacheTimestamp = [datetime]::MinValue
        $this.UsedCacheState = $false
        $this.Metadata = @{
            version = "1.0.0"
            planId = [guid]::NewGuid().ToString()
        }
    }
    
    DLPaCPlan([string]$PlanPath) {
        $this.Changes = [System.Collections.ArrayList]::new()
        $this.PlanPath = $PlanPath
        $this.CreatedAt = [datetime]::UtcNow
        $this.CacheTimestamp = [datetime]::MinValue
        $this.UsedCacheState = $false
        $this.Metadata = @{
            version = "1.0.0"
            planId = [guid]::NewGuid().ToString()
        }
    }

    [void] SetCacheInfo([datetime]$Timestamp, [bool]$UsedCache) {
        $this.CacheTimestamp = $Timestamp
        $this.UsedCacheState = $UsedCache
    }

    [bool] UsedCache() {
        return $this.UsedCacheState
    }

    [datetime] GetCacheTimestamp() {
        return $this.CacheTimestamp
    }
    
    [void] AddChange([DLPaCPlanItem]$Change) {
        $this.Changes.Add($Change)
    }
    
    [void] AddPolicyCreate([object]$Policy) {
        $change = [DLPaCPlanItem]::new("Create", "Policy", $Policy.Name)
        $change.NewState = $Policy.ToHashtable()
        $change.ChangeReason = "New policy"
        $this.AddChange($change)
    }
    
    [void] AddPolicyUpdate([object]$Policy, [hashtable]$OldState, [string]$Reason) {
        $change = [DLPaCPlanItem]::new("Update", "Policy", $Policy.Name)
        $change.OldState = $OldState
        $change.NewState = $Policy.ToHashtable()
        $change.ChangeReason = $Reason
        $this.AddChange($change)
    }
    
    [void] AddPolicyDelete([string]$PolicyName, [hashtable]$OldState) {
        $change = [DLPaCPlanItem]::new("Delete", "Policy", $PolicyName)
        $change.OldState = $OldState
        $change.ChangeReason = "Policy removal requested"
        $this.AddChange($change)
    }
    
    [void] AddRuleCreate([object]$Rule, [string]$PolicyName) {
        $change = [DLPaCPlanItem]::new("Create", "Rule", $Rule.Name)
        $change.ParentResource = $PolicyName
        $change.NewState = $Rule.ToHashtable()
        $change.ChangeReason = "New rule"
        $this.AddChange($change)
    }
    
    [void] AddRuleUpdate([object]$Rule, [string]$PolicyName, [hashtable]$OldState, [string]$Reason) {
        $change = [DLPaCPlanItem]::new("Update", "Rule", $Rule.Name)
        $change.ParentResource = $PolicyName
        $change.OldState = $OldState
        $change.NewState = $Rule.ToHashtable()
        $change.ChangeReason = $Reason
        $this.AddChange($change)
    }
    
    [void] AddRuleDelete([string]$RuleName, [string]$PolicyName, [hashtable]$OldState) {
        $change = [DLPaCPlanItem]::new("Delete", "Rule", $RuleName)
        $change.ParentResource = $PolicyName
        $change.OldState = $OldState
        $change.ChangeReason = "Rule removal requested"
        $this.AddChange($change)
    }
    
    [bool] HasChanges() {
        return $this.Changes.Count -gt 0
    }
    
    [int] GetChangeCount() {
        return $this.Changes.Count
    }
    
    [int] GetChangeCountByOperation([string]$Operation) {
        return ($this.Changes | Where-Object { $_.Operation -eq $Operation }).Count
    }
    
    [int] GetChangeCountByResourceType([string]$ResourceType) {
        return ($this.Changes | Where-Object { $_.ResourceType -eq $ResourceType }).Count
    }
    
    [void] Save() {
        if (-not $this.PlanPath) {
            throw "Plan path not set"
        }
        
        # Create plan object
        $planObject = [PSCustomObject]@{
            metadata = $this.Metadata
            createdAt = $this.CreatedAt.ToString('o')
            cacheInfo = @{
                timestamp = if ($this.CacheTimestamp) { $this.CacheTimestamp.ToString('o') } else { $null }
                usedCache = $this.UsedCacheState
            }
            changes = $this.Changes | ForEach-Object {
                [PSCustomObject]@{
                    operation = $_.Operation
                    resourceType = $_.ResourceType
                    resourceName = $_.ResourceName
                    parentResource = $_.ParentResource
                    oldState = $_.OldState
                    newState = $_.NewState
                    changeReason = $_.ChangeReason
                }
            }
        }
        
        # Save plan to file
        $planJson = $planObject | ConvertTo-Json -Depth 10
        $planJson | Out-File -FilePath $this.PlanPath -Encoding utf8 -Force
    }
    
    [string] GenerateSummary() {
        $summary = [System.Text.StringBuilder]::new()
        
        $summary.AppendLine("Plan: $($this.GetChangeCount()) changes")
        $summary.AppendLine("")
        
        $createCount = $this.GetChangeCountByOperation("Create")
        $updateCount = $this.GetChangeCountByOperation("Update")
        $deleteCount = $this.GetChangeCountByOperation("Delete")
        
        $summary.AppendLine("  Create: $createCount")
        $summary.AppendLine("  Update: $updateCount")
        $summary.AppendLine("  Delete: $deleteCount")
        $summary.AppendLine("")
        
        if ($this.Changes.Count -gt 0) {
            $summary.AppendLine("Changes:")
            
            foreach ($change in $this.Changes) {
                $summary.AppendLine("  + $change")
            }
        }
        else {
            $summary.AppendLine("No changes. Your infrastructure matches the configuration.")
        }
        
        return $summary.ToString()
    }
    
    static [DLPaCPlan] Load([string]$PlanPath) {
        $plan = [DLPaCPlan]::new($PlanPath)
        
        if (Test-Path $PlanPath) {
            try {
                $planJson = Get-Content -Path $PlanPath -Raw
                $planObject = $planJson | ConvertFrom-Json
                
                if ($planObject.metadata) {
                    # Convert PSCustomObject to Hashtable
                    $plan.Metadata = ConvertTo-Hashtable -InputObject $planObject.metadata
                }
                
                if ($planObject.createdAt) {
                    $plan.CreatedAt = [datetime]$planObject.createdAt
                }

                if ($planObject.cacheInfo) {
                    if ($planObject.cacheInfo.timestamp) {
                        $plan.CacheTimestamp = [datetime]$planObject.cacheInfo.timestamp
                    }
                    $plan.UsedCacheState = [bool]$planObject.cacheInfo.usedCache
                }
                
                if ($planObject.changes) {
                    foreach ($changeObj in $planObject.changes) {
                        $change = [DLPaCPlanItem]::new()
                        $change.Operation = $changeObj.operation
                        $change.ResourceType = $changeObj.resourceType
                        $change.ResourceName = $changeObj.resourceName
                        $change.ParentResource = $changeObj.parentResource
                        
                        # Use PSCustomObjects directly
                        $change.OldState = $changeObj.oldState
                        $change.NewState = $changeObj.newState
                        $change.ChangeReason = $changeObj.changeReason
                        
                        $plan.AddChange($change)
                    }
                }
            }
            catch {
                throw "Failed to load plan file: $_"
            }
        }
        
        return $plan
    }
}


