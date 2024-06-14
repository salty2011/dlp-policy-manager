function Get-EmailConditions {
    param($EmailRules)

    $EmailRules.Keys | ForEach-Object {
        $parentKey = $_
        $EmailRules[$_].Keys | ForEach-Object {
            $childKey = $_
            if($EmailRules[$parentKey][$childKey]){
                Get-DLPCondition -Key $scriptConfig.SubConditions.email[$parentKey][$childKey] -Value $EmailRules[$parentKey][$childKey]
            }
        }
    }
}
