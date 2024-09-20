<#
.SYNOPSIS
    Imports tenant configuration from a YAML file and selects a specific tenant based on the provided name.

.DESCRIPTION
    The Import-DPMTenantConfig function reads a YAML file containing tenant configurations, 
    attempts to find a tenant by name, and returns the tenant's details. It's useful for scripts 
    that require tenant-specific information to perform operations.

.PARAMETER Path
    Specifies the path to the YAML file containing tenant configurations.

.PARAMETER TenantName
    Specifies the name of the tenant to retrieve information for.

.EXAMPLE
    $tenantData = Import-DPMTenantConfig -Path "C:\Path\To\env.yml" -TenantName "TEST"
    This example loads tenant configurations from the specified YAML file and outputs the configuration
    of the tenant named "TEST".

.OUTPUTS
    PSCustomObject
    If the specified tenant is found, the function returns an object containing tenant details such as
    Name, Organization, AppID, and Thumbprint.

.NOTES
    Ensure that the YAML file is correctly formatted and accessible at the specified path. The function
    will return an error if the tenant is not found or if the YAML content is malformed.
    Example of expected YAML format:
    ```
    tenant:
      - Name: 'TEST'
        Organization: 'test.microsoft.com'
        AppID: '00000000-0000-0000-0000-000000000000'
        Thumbprint: '123456789abcdef'
      - Name: 'TEST2'
        Organization: 'test2.microsoft.com'
        AppID: '11111111-2222-3333-4444-555555555555'
        Thumbprint: 'abcdef123456789'
    ```
#>

function Import-DPMTenantConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$TenantName
    )
    
    begin {
        $selectedTenant = $null

        try {
            $tenant_config = Get-Content -Path $Path -Raw | ConvertFrom-Yaml    
        }
        catch {
            Write-Error "Failed to load the YAML content from '$Path'."
            return
        }
    }
    
    process {
        try {
            $selectedTenant = $tenant_config.tenant | Where-Object { $_.Name -eq $TenantName }

            if ($null -eq $selectedTenant) {
                Write-Error "Tenant '$TenantName' not found."
            } else {
                Write-Verbose "Selected tenant: $($selectedTenant.Name)"
                Write-Verbose "Organization: $($selectedTenant.Organization)"
                Write-Verbose "AppID: $($selectedTenant.AppID)"
                Write-Verbose "Thumbprint: $($selectedTenant.Thumbprint)"
            }
        }
        catch {
            Write-Error "Failed to find the specified tenant '$TenantName'."
        }
    }
    
    end {
        return $selectedTenant
    }
}