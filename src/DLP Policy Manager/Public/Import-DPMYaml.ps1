function Import-DPMYaml {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$Path
    )

    begin{
        $fileFilter = "*.yml"
        $files = Get-ChildItem -Path $Path -Filter $fileFilter
    }

    process(
        foreach ($file in $files){
          $yml = Get-Content -Path $file.FullName -Raw | ConvertFrom-Yaml
          foreach ($policy in $yml.Policies){
            New-DPMDLPPolicy -PolicyData $policy
          }
        }
    )

}