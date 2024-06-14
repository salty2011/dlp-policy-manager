function Get-DLPCondition {
    param($Value, $Key)
    return @{
        ConditionName = $Key
        Value         = $Value
    }
}