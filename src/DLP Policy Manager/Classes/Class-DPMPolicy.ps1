class LocationConfig {
    [ValidateSet('All', 'Specific')][string]$Type
    [string[]]$Inclusions
    [string[]]$Exclusions

    LocationConfig([string]$type, [string[]]$inclusions, [string[]]$exclusions) {
        $this.Type = $type
        $this.Inclusions = $inclusions
        $this.Exclusions = $exclusions
    }
}

class Policy {
    [ValidateNotNullOrEmpty()][string] $Name
    [string] $Description
    [ValidateSet('enable', 'disable', 'audit', 'silent')][string] $Mode
    [hashtable] $Locations
    [bool] $SplitByType
    [int] $Priority
    [string[]] $Rules

    Policy([hashtable] $data) {
        $this.ValidateData($data)
        $this.Name = $data.Name
        $this.Description = $data.Description
        $this.Mode = $data.Mode
        $this.Locations = $this.ProcessLocations($data.Locations)
        $this.SplitByType = $data.SplitByType
        $this.Priority = $data.Priority
        $this.Rules = $data.Rules
    }

    hidden [hashtable] ProcessLocations([hashtable]$locationData) {
        $processedLocations = @{}
        foreach ($location in $locationData.Keys) {
            $config = $locationData[$location]
            $processedLocations[$location] = [LocationConfig]::new(
                $config.Type,
                $config.ContainsKey('Inclusions') ? $config.Inclusions : @(),
                $config.ContainsKey('Exclusions') ? $config.Exclusions : @()
            )
        }
        return $processedLocations
    }

    hidden [void] ValidateData([hashtable]$data) {
        if (-not $data.ContainsKey('Name') -or [string]::IsNullOrWhiteSpace($data.Name)) {
            throw "Policy name is required"
        }

        $validModes = @('enable', 'disable', 'audit', 'silent')
        if ($data.Mode -notin $validModes) {
            throw "Invalid mode '$($data.Mode)'. Valid modes are: $($validModes -join ', ')"
        }

        if (-not $data.ContainsKey('Locations') -or $data.Locations.Count -eq 0) {
            throw "At least one location is required"
        }

        $validLocations = @('Exchange', 'SharePoint', 'OneDrive')
        foreach ($location in $data.Locations.Keys) {
            if ($location -notin $validLocations) {
                throw "Invalid location '$location'. Valid locations are: $($validLocations -join ', ')"
            }
            $this.ValidateLocationConfig($data.Locations[$location])
        }

        if ($data.ContainsKey('Priority') -and -not [int]::TryParse($data.Priority, [ref]$null)) {
            throw "Priority must be an integer"
        }
    }

    hidden [void] ValidateLocationConfig([hashtable]$config) {
        $validTypes = @('All', 'Specific')
        if ($config.Type -notin $validTypes) {
            throw "Invalid location type '$($config.Type)'. Valid types are: All, Specific"
        }

        if ($config.Type -eq 'Specific') {
            if (-not $config.ContainsKey('Inclusions') -or $config.Inclusions.Count -eq 0) {
                throw "Inclusions must be specified when using 'Specific' type"
            }
            if ($config.ContainsKey('Exclusions') -and $config.Exclusions.Count -gt 0) {
                throw "Exclusions should not be specified when using 'Specific' type"
            }
        }

        if ($config.Type -eq 'All' -and $config.ContainsKey('Inclusions') -and $config.Inclusions.Count -gt 0) {
            throw "Inclusions should not be specified when using 'All' type"
        }
    }
}