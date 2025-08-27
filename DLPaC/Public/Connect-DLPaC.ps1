function Connect-DLPaC {
    <#
    .SYNOPSIS
        Start a manual DLPaC session and ensure a single EXO connection is established (idempotent).
    .DESCRIPTION
        Marks a manual session active to prevent auto-disconnects between cmdlets and ensures there is
        an Exchange Online (IPPS) session available. Safe to call multiple times; will no-op if already active.
    #>
    [CmdletBinding()]
    param ()

    # Initialize logger
    if (-not $script:Logger) {
        $script:Logger = [DLPaCLogger]::new()
    }

    # Allow connecting before workspace init; warn if not initialized
    if (-not $script:WorkspacePath) {
        $script:Logger.LogWarning("Workspace not initialized yet; proceeding to connect for manual session.")
    }

    # If manual session already active, no-op
    if ($script:ManualSessionActive) {
        $script:Logger.LogInfo("Manual session already active; reusing existing Exchange Online session")
        return
    }

    # Activate manual session before connecting so downstream finally blocks skip disconnects
    $script:ManualSessionActive = $true

    # Ensure a single EXO connection is established (idempotent)
    $adapter = [DLPaCIPPSPAdapter]::new($script:Logger)
    if (-not $adapter.IsConnected) {
        $ok = $adapter.Connect()
        if (-not $ok) {
            $script:ManualSessionActive = $false
            throw "Failed to connect to Exchange Online."
        }
    }

    $script:Logger.LogInfo("Manual session activated")
}