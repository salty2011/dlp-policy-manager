function Disconnect-DLPaC {
    <#
    .SYNOPSIS
        End a manual DLPaC session and disconnect Exchange Online if connected.
    .DESCRIPTION
        Marks the manual session as inactive and disconnects the Exchange Online (IPPS) session
        if one exists. Safe to call multiple times; will no-op if no manual session is active.
    #>
    [CmdletBinding()]
    param ()

    # Initialize logger
    if (-not $script:Logger) {
        $script:Logger = [DLPaCLogger]::new()
    }

    # Workspace guard (consistent with other public cmdlets)
    if (-not $script:WorkspacePath) {
        $script:Logger.LogError("DLPaC workspace not initialized. Run Initialize-DLPaCWorkspace first.")
        throw "DLPaC workspace not initialized. Run Initialize-DLPaCWorkspace first."
    }

    if (-not $script:ManualSessionActive) {
        $script:Logger.LogInfo("Manual session not active; nothing to disconnect")
        return
    }

    $adapter = [DLPaCIPPSPAdapter]::new($script:Logger)
    if ($adapter.IsConnected) {
        $adapter.Disconnect()
    }

    $script:ManualSessionActive = $false
    $script:Logger.LogInfo("Manual session deactivated")
}