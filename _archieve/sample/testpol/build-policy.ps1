    function Add-PolicyScope {
        param(
            $value,
            $key,
            $output
        )
        if ($value) {
            $output[$key] = $value
        }
    }
    
    function Add-Scopes {
        param(
            $scopes,
            $yml,
            $output
        )
        $scopes.Keys | ForEach-Object {
            if ($null -ne $yml[$_]) {
                Add-PolicyScope -output $output -key $scopes[$_] -value $yml[$_]
            }
        }
    }

    # Define the directory path and file filter
$directoryPath = ".\sample\testpol"
$fileFilter = "*.yml"
$result = @()
# Get all YAML files in the specified directory
$files = Get-ChildItem -Path $directoryPath -Filter $fileFilter

    $files | ForEach-Object {
        $ymlData = Get-Content $_.FullName | ConvertFrom-Yaml
        foreach ($yml in $ymlData.policies) {
            $output = @{
                Name    = $yml.name
                Comment = $yml.description
                Mode    = $scriptConfig.Mode[$yml.mode]
            }
    
            if ($yml["split-by-type"]) {
                $yml.include.Keys | ForEach-Object {
                    if ($yml.include[$_]) {
                        $policy = $output.Clone()
                        $policy.Name += "-$_"
                        Add-Scopes -scopes $scriptConfig.Scopes[$_] -output $policy -yml $yml.include[$_]
                        $result += $policy
                    }
                }
            } else {
                $yml.include.Keys | ForEach-Object {
                    if ($yml.include[$_]) {
                        Add-Scopes -scopes $scriptConfig.Scopes[$_] -output $output -yml $yml.include[$_]
                    }
                }
                $result += $output
            }
    
#            New-Item -ItemType Directory -Path $outputPath -Force -ErrorAction SilentlyContinue | Out-Null
#            $result | ForEach-Object {
#                $_ | Export-Clixml -Path "$outputPath\$($_.Name).xml" -Depth 10
#            }
        }
    }
    