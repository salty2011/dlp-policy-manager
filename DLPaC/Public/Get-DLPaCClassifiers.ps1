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
    $ippspAdapter = [DLPaCIPPSPAdapter]::new($script:Logger)

    try {
        # Connect to Exchange Online
        $script:Logger.LogInfo("Connecting to Exchange Online")
        $connected = $ippspAdapter.Connect()
        
        if (-not $connected) {
            $errorMessage = "Failed to connect to Exchange Online"
            $script:Logger.LogError($errorMessage)
            throw $errorMessage
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
        # Disconnect from Exchange Online if connected
        if ($ippspAdapter.IsConnected) {
            $script:Logger.LogInfo("Disconnecting from Exchange Online")
            $ippspAdapter.Disconnect()
        }
    }
}
