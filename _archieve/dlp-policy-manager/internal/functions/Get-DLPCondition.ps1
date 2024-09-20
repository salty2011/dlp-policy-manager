# TODO: Find correct home for this function
function Get-DLPCondition {
    #TODO: Add help
    param($Value, $Key)
    return @{
        ConditionName = $Key
        Value         = $Value
    }
}