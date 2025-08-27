@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'DLPaC.psm1'
    
    # Version number of this module.
    ModuleVersion = '0.1.0'
    
    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')
    
    # ID used to uniquely identify this module
    GUID = '8a7b9e3f-5d1a-4c8e-9f0a-2d7e4b3c5d6a'
    
    # Author of this module
    Author = 'DLPaC Team'
    
    # Company or vendor of this module
    CompanyName = 'DLPaC Project'
    
    # Copyright statement for this module
    Copyright = '(c) 2025 DLPaC Team. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'DLP-as-Code (DLPaC) module for managing Microsoft 365 DLP policies using infrastructure-as-code principles'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'
    
    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(
        @{
            ModuleName = 'ExchangeOnlineManagement'
            ModuleVersion = '3.0.0'
        },
        @{
            ModuleName = 'powershell-yaml'
            ModuleVersion = '0.4.2'
        }
    )
    
    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Initialize-DLPaCWorkspace',
        'Get-DLPaCPlan',
        'Invoke-DLPaCApply',
        'Invoke-DLPaCDestroy',
        'Test-DLPaCConfiguration',
        'Import-DLPaCExisting',
        'Get-DLPaCClassifiers'
    )
    
    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = '*'
    
    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('DLP', 'M365', 'Security', 'Compliance', 'IaC', 'InfrastructureAsCode')
            
            # A URL to the license for this module.
            LicenseUri = 'https://github.com/DLPaC/DLPaC/blob/main/LICENSE'
            
            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/DLPaC/DLPaC'
            
            # A URL to an icon representing this module.
            # IconUri = ''
            
            # ReleaseNotes of this module
            ReleaseNotes = 'Initial release of the DLPaC module'
        }
    }
}