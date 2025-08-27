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

    # Optional workspace guard (consistent with other public cmdlets)
    if (-not $script:WorkspacePath) {
        $script:Logger.LogError("DLPaC workspace not initialized. Run Initialize-DLPaCWorkspace first.")
        throw "DLPaC workspace not initialized. Run Initialize-DLPaCWorkspace first."
    }

    # If manual session already active, no-op
    if ($script:ManualSessionActive) {
        $script:Logger.LogInfo("Manual session already active; reusing existing Exchange Online session")
        return
    }

    # Ensure a single EXO connection is established (idempotent)
    $adapter = [DLPaCIPPSPAdapter]::new($script:Logger)
    if (-not $adapter.IsConnected) {
        $null = $adapter.Connect()
    }

    $script:ManualSessionActive = $true
    $script:Logger.LogInfo("Manual session activated")
}