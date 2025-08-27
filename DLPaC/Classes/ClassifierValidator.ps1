class DLPaCClassifierValidator {
    [string] $ClassifiersPath
    [System.Collections.Generic.HashSet[string]] $ValidInfoTypes

    DLPaCClassifierValidator([string]$ClassifiersPath) {
        $this.ClassifiersPath = $ClassifiersPath
        $this.LoadClassifiers()
    }

    [void] LoadClassifiers() {
        if (-not (Test-Path $this.ClassifiersPath)) {
            throw "Classifier cache not found: $($this.ClassifiersPath)"
        }
        $json = Get-Content -Path $this.ClassifiersPath -Raw | ConvertFrom-Json
        $this.ValidInfoTypes = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($c in $json) {
            if ($c.Identity) { $this.ValidInfoTypes.Add($c.Identity) }
            if ($c.Name) { $this.ValidInfoTypes.Add($c.Name) }
        }
    }

    [bool] IsValidInfoType([string]$infoType) {
        return $this.ValidInfoTypes.Contains($infoType)
    }


}
