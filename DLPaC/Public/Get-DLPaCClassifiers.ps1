function Get-DLPaCClassifiers {
    <#
    .SYNOPSIS
        Fetches available DLP classifiers (sensitive information types) from the connected tenant.
    .DESCRIPTION
        Uses Microsoft Purview/Exchange Online cmdlets to retrieve all available sensitive information types/classifiers.
        Outputs them as an array of hashtables with Name, Id, and Description.
    #>
    [CmdletBinding()]
    param ()

    # Initialize IPPSP adapter and logger
    if (-not $script:Logger) {
        $script:Logger = [DLPaCLogger]::new()
    }
    # Reuse cached adapter created by Connect-DLPaC when available to avoid creating a fresh adapter
    if ($script:IPPSPAdapter) {
        $ippspAdapter = $script:IPPSPAdapter
    }
    else {
        $ippspAdapter = [DLPaCIPPSPAdapter]::new($script:Logger)
    }

    try {
        # Prefer existing session when manual session is active to avoid extra prompts
        $connected = $false
        if ($script:ManualSessionActive) {
            # If the cached adapter already reports connected, trust it and avoid calling Get-IPPSSession
            if ($ippspAdapter.IsConnected) {
                $connected = $true
                $script:Logger.LogInfo("Using cached IPPSP adapter connection (manual session active)")
            }
            else {
                try {
                    $null = Get-IPPSSession -ErrorAction Stop
                    $connected = $true
                    $script:Logger.LogInfo("Using existing Exchange Online session (manual session active)")
                } catch {
                    $connected = $false
                }
            }
        }
        if (-not $connected) {
            # Ensure connection (idempotent; no-op if already connected)
            $connected = $ippspAdapter.Connect()
            if (-not $connected) {
                $errorMessage = "Failed to connect to Exchange Online"
                $script:Logger.LogError($errorMessage)
                throw $errorMessage
            }
        }

        # Try to use Get-DlpSensitiveInformationType if available
        if (Get-Command Get-DlpSensitiveInformationType -ErrorAction SilentlyContinue) {
            $classifiers = Get-DlpSensitiveInformationType | Select-Object Identity, Name, Id, Description, Publisher, Type, Classifier, State, Capability, LocalizedName, AllLocalizedNames, AllLocalizedDescriptions, RulePackId, FormalName
        }
        elseif (Get-Command Get-DlpSensitiveInformationType -Module ExchangeOnlineManagement -ErrorAction SilentlyContinue) {
            $classifiers = Get-DlpSensitiveInformationType | Select-Object Identity, Name, Id, Description, Publisher, Type, Classifier, State, Capability, LocalizedName, AllLocalizedNames, AllLocalizedDescriptions, RulePackId, FormalName
        }
        else {
            Write-Error "No supported cmdlet found for retrieving DLP classifiers. Ensure you are connected to Exchange Online or Microsoft Purview."
            return
        }

        $classifiers | ForEach-Object {
            [PSCustomObject]@{
                Identity    = $_.Identity
                Name        = $_.Name
                Type        = $_.Type
                State       = $_.State
                Capability  = $_.Capability
            }
        }
    }
    finally {
        # Disconnect from Exchange Online only when not in a manual session
        if (-not $script:ManualSessionActive -and $ippspAdapter.IsConnected) {
            $script:Logger.LogInfo("Disconnecting from Exchange Online")
            $ippspAdapter.Disconnect()
        }
    }
}
