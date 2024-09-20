function New-DPMDLPPolicy {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$PolicyData
    )

    return [Policy]::new($PolicyData)
}