function Check-Requirements {
    [CmdletBinding()]
    param (
        [string]$RequirementsFilePath = "requirements.txt",
        [switch]$InstallMissing
    )

    # Set the verbose preference if the -Verbose switch is used
    if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose')) {
        $VerbosePreference = 'Continue'
    }

    # Function to read and parse the requirements file
    function Parse-RequirementsFile {
        [CmdletBinding()]
        param (
            [string]$FilePath
        )
        $requirements = @{}
        if (Test-Path $FilePath) {
            $content = Get-Content -Path $FilePath
            foreach ($line in $content) {
                if ($line -match '^(.*?)([=<>]+)(.*?)$') {
                    $moduleName = $matches[1].Trim()
                    $versionOperator = $matches[2].Trim()
                    $moduleVersion = $matches[3].Trim()
                    $requirements[$moduleName] = [ordered]@{
                        Operator = $versionOperator
                        Version = $moduleVersion
                    }
                }
            }
        } else {
            Write-Error "Requirements file not found: $FilePath"
            exit 1
        }
        return $requirements
    }

    # Function to check if a module is installed with the correct version
    function Check-Module {
        [CmdletBinding()]
        param (
            [string]$ModuleName,
            [string]$VersionOperator,
            [version]$RequiredVersion
        )
        $modules = Get-Module -ListAvailable -Name $ModuleName -Verbose:$false
        # Write-Verbose -Message "'Found versions for ' $ModuleName': '$($modules.Version -join ', ')"
        foreach ($module in $modules) {
            switch ($VersionOperator) {
                '=' {
                    if ($module.Version -eq $RequiredVersion) {
                        return $true
                    }
                }
                '=>' {
                    if ($module.Version -ge $RequiredVersion) {
                        return $true
                    }
                }
                '=<' {
                    if ($module.Version -le $RequiredVersion) {
                        return $true
                    }
                }
            }
        }
        return $false
    }

    # Function to install or update a module
    function Install-ModuleIfNeeded {
        [CmdletBinding()]
        param (
            [string]$ModuleName,
            [string]$VersionOperator,
            [string]$RequiredVersion
        )
        if (-not (Check-Module -ModuleName $ModuleName -VersionOperator $VersionOperator -RequiredVersion $RequiredVersion)) {
            Write-Verbose "Installing or updating module: $ModuleName to version $RequiredVersion"
            Install-Module -Name $ModuleName -RequiredVersion $RequiredVersion -Force -Scope CurrentUser -Verbose
        } else {
            Write-Verbose "Module $ModuleName with version $VersionOperator $RequiredVersion is already installed."
        }
    }

    # Read and parse the requirements file
    $requirements = Parse-RequirementsFile -FilePath $RequirementsFilePath

    # Check modules and optionally install/update them
    foreach ($moduleName in $requirements.Keys) {
        $versionOperator = $requirements[$moduleName].Operator
        $requiredVersion = [version]$requirements[$moduleName].Version
        # Write-Verbose "Checking module: $moduleName, required version: $versionOperator $requiredVersion"
        if (-not (Check-Module -ModuleName $moduleName -VersionOperator $versionOperator -RequiredVersion $requiredVersion)) {
             Write-Warning "Module $moduleName with version $versionOperator $requiredVersion is not installed."
            if ($InstallMissing.IsPresent) {
                Install-ModuleIfNeeded -ModuleName $moduleName -VersionOperator $versionOperator -RequiredVersion $requiredVersion
            }
        } else {
            Write-Verbose "Module $moduleName with version $versionOperator $requiredVersion is already installed."
        }
    }

    if ($InstallMissing.IsPresent) {
        Write-Verbose "All required modules are checked and installed/updated as necessary."
    } else {
        Write-Verbose "Module check completed. Use -InstallMissing to install missing dependencies."
    }
}
