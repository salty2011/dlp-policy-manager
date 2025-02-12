function Connect-DPMTenant {
    <#
    .SYNOPSIS
        Connects to a DPM tenant using the configuration specified in a YAML file.

    .DESCRIPTION
        This function reads a YAML configuration file to find tenant settings for a specified environment and uses these settings to establish a session connection.

    .PARAMETER Path
        The path to the YAML configuration file. Defaults to '.\env.yml' if not specified.

    .PARAMETER Environment
        The name of the environment to which the function should connect. This is matched against the 'Name' property of tenants defined in the YAML file.

    .EXAMPLE
        Connect-DPMTenant -Environment "Production"
        Connects to the Production environment using settings from the default YAML file.

    .EXAMPLE
        Connect-DPMTenant -Path "C:\configs\tenant.yml" -Environment "Development"
        Connects to the Development environment using settings from the specified YAML file.

    .NOTES
        Ensure that the YAML file is properly formatted and that each tenant entry includes 'Name', 'AppID', 'CertificateThumbprint', and 'Organization' properties.

    .LINK
        Connect-IPPSSession
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateScript({
            if (Test-Path $_) { $true }
            else { throw "Configuration file not found at: $_" }
        })]
        [string]$Path = '.\env.yml',

        [Parameter(Mandatory = $true)]
        [string]$Environment
    )

    process {
        try {
            Write-Verbose "Reading configuration from $Path"
            # Read and convert the YAML file into a PowerShell object
            $envConfigs = Get-Content -Path $Path | ConvertFrom-Yaml

            # Assuming $envConfigs contains a property 'tenant' that is an array of objects
            $selectedTenant = $envConfigs.tenant | Where-Object { $_.Name -eq $Environment }

            # Check if tenant data was found
            if ($selectedTenant) {
                # Validate required properties
                $requiredProps = @('AppID', 'Thumbprint', 'Organization')
                $missingProps = $requiredProps | Where-Object { -not $selectedTenant.$_ }

                if ($missingProps) {
                    throw "Missing required properties in tenant configuration: $($missingProps -join ', ')"
                }

                Write-Verbose "Attempting to connect to $Environment ($($selectedTenant.Organization))"
                # Using the found tenant data to connect
                $connection = Connect-IPPSSession -AppId $selectedTenant.AppID `
                                                -CertificateThumbprint $selectedTenant.Thumbprint `
                                                -Organization $selectedTenant.Organization `
                                                -ErrorAction Stop *> $null

                Write-Output "Connected to $Environment on $($selectedTenant.Organization)"
            } else {
                Write-Warning "No tenant configuration found for environment: $Environment"
                Write-Verbose "Available environments: $($envConfigs.tenant.Name -join ', ')"
            }
        } catch {
            Write-Error "An error occurred while trying to connect to the tenant: $_"
            Write-Verbose $_.ScriptStackTrace
        }
    }
}