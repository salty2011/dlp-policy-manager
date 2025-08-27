class DLPaCLogger {
    [string] $LogPath
    [string] $LogLevel
    [bool] $EnableConsole
    [bool] $EnableFile
    
    # Log level constants
    static [string] $ERROR = "Error"
    static [string] $WARNING = "Warning"
    static [string] $INFO = "Information"
    static [string] $VERBOSE = "Verbose"
    static [string] $DEBUG = "Debug"
    
    # Log level numeric values for comparison
    hidden [hashtable] $LogLevelValue = @{
        "Error" = 1
        "Warning" = 2
        "Information" = 3
        "Verbose" = 4
        "Debug" = 5
    }
    
    DLPaCLogger() {
        $this.LogLevel = [DLPaCLogger]::INFO
        $this.EnableConsole = $true
        $this.EnableFile = $false
    }
    
    DLPaCLogger([string]$LogPath) {
        $this.LogPath = $LogPath
        $this.LogLevel = [DLPaCLogger]::INFO
        $this.EnableConsole = $true
        $this.EnableFile = $true
    }
    
    [void] SetLogLevel([string]$LogLevel) {
        if ($this.LogLevelValue.ContainsKey($LogLevel)) {
            $this.LogLevel = $LogLevel
        }
        else {
            throw "Invalid log level: $LogLevel. Valid values are: Error, Warning, Information, Verbose, Debug"
        }
    }
    
    [void] EnableFileLogging([string]$LogPath) {
        $this.LogPath = $LogPath
        $this.EnableFile = $true
        
        # Create log directory if it doesn't exist
        $logDir = Split-Path -Path $LogPath -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
    }
    
    [void] DisableFileLogging() {
        $this.EnableFile = $false
    }
    
    [void] EnableConsoleLogging() {
        $this.EnableConsole = $true
    }
    
    [void] DisableConsoleLogging() {
        $this.EnableConsole = $false
    }
    
    [bool] ShouldLog([string]$Level) {
        return $this.LogLevelValue[$Level] -le $this.LogLevelValue[$this.LogLevel]
    }
    
    [void] LogError([string]$Message) {
        $this.Log([DLPaCLogger]::ERROR, $Message)
    }
    
    [void] LogWarning([string]$Message) {
        $this.Log([DLPaCLogger]::WARNING, $Message)
    }
    
    [void] LogInfo([string]$Message) {
        $this.Log([DLPaCLogger]::INFO, $Message)
    }
    
    [void] LogVerbose([string]$Message) {
        $this.Log([DLPaCLogger]::VERBOSE, $Message)
    }
    
    [void] LogDebug([string]$Message) {
        $this.Log([DLPaCLogger]::DEBUG, $Message)
    }
    
    [void] Log([string]$Level, [string]$Message) {
        if (-not $this.ShouldLog($Level)) {
            return
        }
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$Level] $Message"
        
        # Console output with color
        if ($this.EnableConsole) {
            $color = switch ($Level) {
                "Error" { "Red" }
                "Warning" { "Yellow" }
                "Information" { "White" }
                "Verbose" { "Gray" }
                "Debug" { "DarkGray" }
                default { "White" }
            }
            
            Write-Host $logEntry -ForegroundColor $color
        }
        
        # File output
        if ($this.EnableFile -and $this.LogPath) {
            Add-Content -Path $this.LogPath -Value $logEntry
        }
    }
    
    [void] LogException([System.Exception]$Exception, [string]$Context) {
        $message = "Exception in $Context`: $($Exception.Message)"
        $this.LogError($message)
        
        if ($this.ShouldLog([DLPaCLogger]::DEBUG)) {
            $this.LogDebug("Stack trace: $($Exception.StackTrace)")
            
            # Log inner exception if present
            if ($Exception.InnerException) {
                $this.LogDebug("Inner exception: $($Exception.InnerException.Message)")
                $this.LogDebug("Inner stack trace: $($Exception.InnerException.StackTrace)")
            }
        }
    }
}