function Get-ContentConditions {
    param($ContentConditionRules)

    $subCondition = @{
        ConditionName = $dpm_rule_config.SubConditions.content
        Value         = @()
    }

    $groupConditions = @{
        Groups   = @()
        Operator = $ContentConditionRules.operator
    }

    $ContentConditionRules.groups | ForEach-Object {
        $group = @{
            Name     = $_.name
            Operator = $_.operator
        }
        if ($_.type) {
            ## sensitive type
            $group.Sensitivetypes = $_.type | Select-Object @{n = "Name"; e = { $_.name } }, @{n = "ConfidenceLevel"; e = { $_.confidence } }, @{n = "Mincount"; e = { 1 } }, @{n = "Maxcount"; e = { 1 } }   
        }
        if ($_.labels) {
            ## sensitivity labels
            $group.labels = @($_.labels) | Foreach-Object {
                @{
                    name = $_.name
                    type = "Sensitivity"
                }
            }
        }
        $groupConditions.Groups += $group
    }

    $subCondition.Value += $groupConditions

    return $subCondition
}
