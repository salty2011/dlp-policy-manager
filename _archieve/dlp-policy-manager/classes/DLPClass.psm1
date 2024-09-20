#DLP OBJECT CLASSES
class Policy {
    [ValidateNotNullOrEmpty()][string] $Name
    [string] $Description
    [ValidateSet('enable', 'disable', 'audit', 'silent')][string] $Mode
    [ValidateNotNull()][hashtable]$Include
    [hashtable]$Exclude
    [bool] $SplitByType

    Policy([hashtable] $data) {
        $this.ValidateData($data)
        $this.Name = $data.Name
        $this.Description = $data.Description
        $this.Mode = $data.Mode
        $this.Include = $data.Include
        $this.Exclude = $data.Exclude
        $this.SplitByType = $data.SplitByType
    }

    hidden [void] ValidateData([hashtable]$data) {
        if (-not $data.ContainsKey('name') -or [string]::IsNullOrWhiteSpace($data.Name)) { throw "Policy name is required" }
        
        $validModes = @('enable', 'disable', 'audit', 'silent')
        if ($data.Mode -notin $validModes) {
            throw "Invalid mode '$($data.Mode)'. Valid modes are: $($validModes -join ', ')"
        }

        if (-not $data.ContainsKey('include') -or [string]::IsNullOrWhiteSpace($data.include)) { throw "Policy include is required" }

        $validLocations = @('exchange', 'sharepoint', 'onedrive', 'teams')
        foreach ($location in $data.include.Keys) {
            if ($location -notin $validLocations) {
                throw "Invalid location '$location' in policy"
            }
        }
    }
}


#MAIN DLP CONFIG CLASS
class DLPConfig {
    [System.Collections.Generic.List[Policy]]$Policies
    #[System.Collections.Generic.List[DLPRule]]$Rules
    #[System.Collections.Generic.List[DLPLabel]]$Labels
    #[System.Collections.Generic.List[DLPClassifier]]$Classifiers

    DLPConfig() {
        $this.Policies = [System.Collections.Generic.List[Policy]]::new()
        #$this.Rules = [System.Collections.Generic.List[DLPRule]]::new()
        #$this.Labels = [System.Collections.Generic.List[DLPLabel]]::new()
        #$this.Classifiers = [System.Collections.Generic.List[DLPClassifier]]::new()
    }
}