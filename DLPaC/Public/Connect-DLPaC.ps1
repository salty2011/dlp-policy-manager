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

    # Ensure IPPS (Security & Compliance) DLP cmdlets are available for this manual session
    try {
        if (-not (Get-Command Get-DlpCompliancePolicy -ErrorAction SilentlyContinue)) {
            $script:Logger.LogInfo("Connecting to Security & Compliance (IPPS) to enable DLP cmdlets...")
            $ippsParams = @{}
            if ($adapter.TenantId) { $ippsParams.Organization = $adapter.TenantId }
            Connect-IPPSSession @ippsParams -ErrorAction Stop
        }
        if (-not (Get-Command Get-DlpCompliancePolicy -ErrorAction SilentlyContinue)) {
            $script:Logger.LogWarning("IPPS connected but DLP cmdlets not found; DLP operations may fail.")
        } else {
            $script:Logger.LogInfo("Security & Compliance DLP cmdlets available")
        }
    } catch {
        $script:Logger.LogWarning("Failed to establish IPPS session for DLP cmdlets: $_")
    }

    # Cache the adapter for reuse by other cmdlets during a manual session
    $script:IPPSPAdapter = $adapter

    $script:Logger.LogInfo("Manual session activated")
}