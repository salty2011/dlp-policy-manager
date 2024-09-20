function Build-DPMPolicy {
    <#
    .SYNOPSIS
        Builds DLP policies from YAML files within a specified directory.

    .DESCRIPTION
        This function reads YAML files containing policy definitions, processes them according to specified criteria,
        and returns the compiled list of policy objects.

    .PARAMETER Path
        Specifies the directory path where the YAML policy files are located.

    .EXAMPLE
        $policies = Build-DPMPolicy -Path "C:\Policies"

    .NOTES
        Ensure that each YAML file is properly formatted according to the expected schema for DLP policies.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$Path
    )
    
    begin {
        [System.Collections.Generic.List[object]]$result = @()
        $fileFilter = "*.yml"
        $files = Get-ChildItem -Path $Path -Filter $fileFilter
    }
    
    process {
        foreach ($file in $files) {
            try {
                $ymlData = Get-Content $file.FullName | ConvertFrom-Yaml
                foreach ($yml in $ymlData.policy) {
                    $policy = [PSCustomObject]@{
                        Name = $yml.name
                        Mode = $yml.mode
                        Comment = $yml.description
                        ExchangeLocation = if ($yml.include.exchange.location -eq 'all') { 'All' } else { $yml.include.exchange.location }
                        TeamsLocation = if ($yml.include.teams.location -eq 'all') { 'All' } else { $yml.include.teams.location }
                        SharePointLocation = if ($yml.include.sharepoint.location -eq 'all') { 'All' } else { $yml.include.sharepoint.location }
                        OneDriveLocation = if ($yml.include.onedrive.location -eq 'all') { 'All' } else { $yml.include.onedrive.location }
                        SplitByType = $yml.'split-by-type'
                    }

                    $result.Add($policy)
                }
            } catch {
                Write-Error "Failed to process file '$($file.FullName)': $_"
            }
        } 
    }
    
    end {
        return $result
    }
}
