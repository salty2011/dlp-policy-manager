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
            Sensitivetypes = @()  # Ensuring array structure for sensitive types
            Labels = @()          # Ensuring array structure for labels
        }
        
        # Processing sensitive types
        if ($_.type) {
            foreach ($type in $_.type) { #TODO: Update to to use SIT
                $group.Sensitivetypes += @{
                    Name = $type.name
                    ConfidenceLevel = $type.confidence
                    Mincount = 1
                    Maxcount = 1
                }
            }
        }

        # Processing labels
        if ($_.labels) {
            foreach ($label in $_.labels) {
                $group.Labels += @{
                    name = $label.name
                    id = $Label.id
                    type = "Sensitivity"
                }
            }
        }

        $groupConditions.Groups += $group
    }

    $subCondition.Value += $groupConditions

    return $subCondition
}
