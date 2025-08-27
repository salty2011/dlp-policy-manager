<# 
 Phase 1 AST foundational classes for enhanced AdvancedRule generation.
 Future phases will extend these with richer logical operators (AnyOf, ExceptAnyOf),
 normalization, validation, and action/endpoint integrations.
#>

class DLPConditionNode {
    [string] $Type
    [object] $SourceCondition   # Original DLPaCCondition instance
    [hashtable] $Metadata

    DLPConditionNode() {
        $this.Metadata = @{}
    }

    # Use [object] to avoid load-order type resolution issues in Phase 1
    DLPConditionNode([object] $Condition) {
        $this.SourceCondition = $Condition
        if ($null -ne $Condition -and ($Condition | Get-Member -Name Type -ErrorAction SilentlyContinue)) {
            $this.Type = $Condition.Type
        }
        $this.Metadata = @{}
    }

    hidden [hashtable] BuildSensitiveInfoSubCondition() {
        $cond = $this.SourceCondition
        return @{
            ConditionName = "ContentContainsSensitiveInformation"
            Value = @(
                @{
                    groups = @(
                        @{
                            name = "Default"
                            operator = "Or"
                            sensitivetypes = @(
                                @{
                                    name = if ($this.Type -eq "ContentContainsPattern") { $cond.Pattern } else { $cond.InfoType }
                                    minCount = $cond.MinCount
                                }
                            )
                        }
                    )
                }
            )
        }
    }

    [hashtable] ToSubConditionJson() {
        $cond = $this.SourceCondition
        if (-not $cond) { throw "Condition node has no source condition." }
        switch ($this.Type) {
            { $_ -in @("ContentContainsPattern", "SensitiveInfoType") } { return $this.BuildSensitiveInfoSubCondition() }
            "RecipientDomain" {
                if ($cond.Operator -eq "NotEquals") {
                    return @{
                        Operator = "Not"
                        SubConditions = @(
                            @{
                                ConditionName = "RecipientDomainIs"
                                Value = @($cond.Value)
                            }
                        )
                    }
                }
                return @{
                    ConditionName = "RecipientDomainIs"
                    Value = @($cond.Value)
                }
            }
            "AccessScope" {
                return @{
                    ConditionName = "AccessScope"
                    Value = @($cond.Value)
                }
            }
            default {
                throw "Unsupported condition type in Phase 1 AST: $($this.Type)"
            }
        }
        return $null
    }
}

class DLPLogicalGroup {
    [string] $Type   # For Phase 1 always 'AllOf'
    [System.Collections.ArrayList] $Children
    [hashtable] $Metadata

    DLPLogicalGroup() {
        $this.Type = "AllOf"
        $this.Children = [System.Collections.ArrayList]::new()
        $this.Metadata = @{}
    }

    [void] AddChild([DLPConditionNode] $Child) {
        if ($null -eq $Child) { return }
        [void]$this.Children.Add($Child)
    }

    [string] GetOperator() {
        switch ($this.Type) {
            "AllOf" { return "And" }
            default { return "And" } # Future: AnyOf -> Or, ExceptAnyOf -> Not
        }
        return "And"
    }

    [hashtable] ToJson() {
        # Phase 1: only simple AND root; SubConditions array of each child condition mapping
        return @{
            Operator = $this.GetOperator()
            SubConditions = @(
                $this.Children | ForEach-Object { $_.ToSubConditionJson() }
            )
        }
    }
}

class DLPRuleAST {
    [DLPLogicalGroup] $RootCondition
    [System.Collections.ArrayList] $Actions
    [hashtable] $Metadata

    DLPRuleAST() {
        $this.RootCondition = [DLPLogicalGroup]::new()
        $this.Actions = [System.Collections.ArrayList]::new()
        $this.Metadata = @{}
    }

    [bool] Validate() {
        # Phase 1 minimal validation
        return ($this.RootCondition.Children.Count -gt 0)
    }

    [DLPRuleAST] Normalize() {
        # Placeholder for future normalization passes
        return $this
    }

    [string] ToAdvancedRuleJson() {
        if (-not $this.Validate()) {
            throw "DLPRuleAST validation failed (no conditions)."
        }
        $rule = @{
            Version = "1.0"
            Condition = $this.RootCondition.ToJson()
        }
        return ($rule | ConvertTo-Json -Depth 15)
    }
}