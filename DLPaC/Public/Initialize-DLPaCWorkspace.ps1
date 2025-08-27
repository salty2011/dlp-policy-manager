function Initialize-DLPaCWorkspace {
    <#
    .SYNOPSIS
        Initializes a DLPaC workspace in the current directory.
    
    .DESCRIPTION
        The Initialize-DLPaCWorkspace function creates the necessary folder structure and files
        for a DLPaC workspace. This includes creating the config, state, and plan directories,
        as well as initializing an empty state file.
    
    .PARAMETER Path
        The path where the workspace should be initialized. If not specified, the current directory is used.
    
    .PARAMETER TenantName
        The name of the Microsoft 365 tenant to connect to. This is typically in the format 'contoso.onmicrosoft.com'.
    
    .PARAMETER Environment
        The environment name to use for this workspace. This helps distinguish between different environments
        like 'development', 'test', or 'production'.
    
    .PARAMETER Force
        If specified, overwrites any existing workspace files.
    
    .EXAMPLE
        Initialize-DLPaCWorkspace -TenantName "contoso.onmicrosoft.com" -Environment "production"
        
        Initializes a DLPaC workspace in the current directory for the contoso.onmicrosoft.com tenant
        in the production environment.
    
    .EXAMPLE
        Initialize-DLPaCWorkspace -Path "C:\DLP\Workspace" -TenantName "fabrikam.onmicrosoft.com" -Environment "development" -Force
        
        Initializes a DLPaC workspace in the specified directory for the fabrikam.onmicrosoft.com tenant
        in the development environment, overwriting any existing files.
    
    .NOTES
        This function must be called before using other DLPaC functions like Get-DLPaCPlan or Invoke-DLPaCApply.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [string]$Path = (Get-Location).Path,
        
        [Parameter(Mandatory = $true)]
        [string]$TenantName,
        
        [Parameter(Mandatory = $true)]
        [string]$Environment,
        
        [Parameter()]
        [switch]$Force
    )
    
    begin {
        # Initialize logger
        if (-not $script:Logger) {
            $script:Logger = [DLPaCLogger]::new()
        }
        
        $script:Logger.LogInfo("Initializing DLPaC workspace at '$Path'")
    }
    
    process {
        try {
            # Create workspace directories
            $directories = @(
                "$Path\.dlpac",
                "$Path\.dlpac\state",
                "$Path\.dlpac\plans",
                "$Path\.dlpac\logs",
                "$Path\configs"
            )
            
            foreach ($dir in $directories) {
                if (-not (Test-Path $dir)) {
                    $script:Logger.LogInfo("Creating directory: $dir")
                    New-Item -Path $dir -ItemType Directory -Force | Out-Null
                }
                else {
                    $script:Logger.LogInfo("Directory already exists: $dir")
                }
            }
            
            # Initialize state file
            $statePath = Join-Path $Path ".dlpac\state\dlpac.state.json"
            if ((Test-Path $statePath) -and -not $Force) {
                $script:Logger.LogWarning("State file already exists. Use -Force to overwrite.")
            }
            else {
                $script:Logger.LogInfo("Initializing state file")
                $state = [DLPaCState]::new($statePath)
                $state.Initialize($TenantName, $Environment)
                
                # Initialize and load tenant cache
                $script:Logger.LogInfo("Initializing tenant state cache")
                try {
                    $state.LoadTenantCache()
                    $script:Logger.LogInfo("Successfully loaded existing tenant cache")
                } catch {
                    $script:Logger.LogWarning("No existing tenant cache found, starting fresh")
                }
                
                $state.Save()
            }
            
            # Create log file
            $logPath = Join-Path $Path ".dlpac\logs\dlpac.log"
            if (-not (Test-Path $logPath) -or $Force) {
                $script:Logger.LogInfo("Initializing log file")
                $null = New-Item -Path $logPath -ItemType File -Force
            }
            
            # Enable file logging
            $script:Logger.EnableFileLogging($logPath)
            
            # Fetch and cache classifiers
            $classifiersPath = Join-Path $Path ".dlpac\state\classifiers.json"
            try {
                $script:Logger.LogInfo("Fetching classifiers from tenant...")
                $classifiers = Get-DLPaCClassifiers
                if ($classifiers) {
                    $classifiers | ConvertTo-Json -Depth 5 | Out-File -FilePath $classifiersPath -Encoding utf8 -Force
                    $script:Logger.LogInfo("Cached $($classifiers.Count) classifiers to $classifiersPath")
                } else {
                    $script:Logger.LogWarning("No classifiers found or failed to fetch classifiers.")
                }
            } catch {
                $script:Logger.LogWarning("Failed to fetch or cache classifiers: $_")
            }

            # Create example config if configs directory is empty
            $configsDir = Join-Path $Path "configs"
            if ((Get-ChildItem -Path $configsDir -File).Count -eq 0) {
                $script:Logger.LogInfo("Creating example configuration file")
                $exampleConfigPath = Join-Path $script:ModuleRoot "Examples\financial-data-policy.yaml"
                $targetConfigPath = Join-Path $configsDir "example-policy.yaml"
                
                if (Test-Path $exampleConfigPath) {
                    Copy-Item -Path $exampleConfigPath -Destination $targetConfigPath -Force
                }
                else {
                    $script:Logger.LogWarning("Example configuration file not found: $exampleConfigPath")
                }
            }
            
            # Create .gitignore file
            $gitignorePath = Join-Path $Path ".gitignore"
            if (-not (Test-Path $gitignorePath) -or $Force) {
                $script:Logger.LogInfo("Creating .gitignore file")
                @"
# DLPaC state and logs
.dlpac/state/
.dlpac/logs/
.dlpac/plans/

# Tenant state cache
.tenant-cache.json

# PowerShell module files
*.psd1
*.psm1

# Credentials
*.cred
"@ | Out-File -FilePath $gitignorePath -Encoding utf8 -Force
            }
            
            # Set workspace path in module variable
            $script:WorkspacePath = $Path
            $script:StatePath = $statePath
            $script:ConfigPath = $configsDir
            $script:LogPath = $logPath
            
            $script:Logger.LogInfo("DLPaC workspace initialized successfully")
            
            # Return workspace info
            [PSCustomObject]@{
                WorkspacePath = $Path
                TenantName = $TenantName
                Environment = $Environment
                StatePath = $statePath
                ConfigPath = $configsDir
                LogPath = $logPath
            }
        }
        catch {
            $script:Logger.LogError("Failed to initialize workspace: $_")
            throw $_
        }
    }
}