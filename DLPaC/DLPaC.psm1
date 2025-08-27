#Requires -Version 5.1
#Requires -Modules @{ ModuleName="ExchangeOnlineManagement"; ModuleVersion="3.0.0" }
#Requires -Modules @{ ModuleName="powershell-yaml"; ModuleVersion="0.4.2" }

# Module import timestamp for logging
$script:ModuleImportTime = Get-Date

# Module base path
$script:ModuleRoot = $PSScriptRoot
$script:ModuleVersion = (Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot 'DLPaC.psd1')).ModuleVersion

# Initialize module-level variables
$script:WorkspacePath = $null
$script:StatePath = $null
$script:ConfigPath = $null
$script:LogPath = $null
$script:SchemaPath = Join-Path $PSScriptRoot 'Schemas'
$script:IPPSPSession = $null
$script:LogLevel = 'Information' # Default log level

# Load module components
Write-Verbose "Loading DLPaC Module v$script:ModuleVersion"

# Load class definitions first (order matters for inheritance)
$ClassFiles = @(
    'BaseClass.ps1',
    'Logger.ps1',
    'SchemaValidator.ps1',
    'Condition.ps1',
    'Action.ps1',
    'RuleAst.ps1',   # Phase 1 AST classes (must load after Condition/Action, before Rule)
    'Rule.ps1',
    'Policy.ps1',
    'State.ps1',
    'Plan.ps1',
    'IPPSPAdapter.ps1'
)

foreach ($ClassFile in $ClassFiles) {
    $ClassPath = Join-Path $PSScriptRoot "Classes\$ClassFile"
    if (Test-Path $ClassPath) {
        try {
            . $ClassPath
            Write-Verbose "Loaded class file: $ClassFile"
        }
        catch {
            Write-Error "Failed to load class file $ClassFile : $_"
        }
    }
    else {
        Write-Verbose "Class file not found: $ClassFile (will be created during development)"
    }
}

# Load private functions
$PrivateFunctions = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue
foreach ($Function in $PrivateFunctions) {
    try {
        . $Function.FullName
        Write-Verbose "Loaded private function: $($Function.BaseName)"
    }
    catch {
        Write-Error "Failed to load private function $($Function.BaseName) : $_"
    }
}

# Load public functions (these will be exported)
$PublicFunctions = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue
foreach ($Function in $PublicFunctions) {
    try {
        . $Function.FullName
        Write-Verbose "Loaded public function: $($Function.BaseName)"
    }
    catch {
        Write-Error "Failed to load public function $($Function.BaseName) : $_"
    }
}

# Initialize module logging
try {
    # Create a default logger that writes to console
    $script:Logger = [DLPaCLogger]::new()
    $script:Logger.LogInfo("DLPaC Module v$script:ModuleVersion loaded successfully")
}
catch {
    Write-Warning "Failed to initialize module logging: $_"
}

# Module cleanup when removed
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    # Perform cleanup when module is removed
    if ($script:IPPSPSession) {
        try {
            Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
            $script:Logger.LogInfo("Disconnected from Exchange Online")
        }
        catch {
            # Ignore errors during cleanup
        }
    }
    
    $script:Logger.LogInfo("DLPaC Module unloaded")
}

# Export public functions
Export-ModuleMember -Function $PublicFunctions.BaseName