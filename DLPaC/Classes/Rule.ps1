<#
    NOTE FOR EDITORS / STATIC ANALYSIS:
    This file depends on classes defined earlier in the module load sequence:
      - BaseClass.ps1  (defines DLPaCBaseObject)
      - Condition.ps1  (defines DLPaCCondition)
      - Action.ps1     (defines DLPaCAction)

    When the module is imported via DLPaC.psm1, these are dot-sourced before Rule.ps1,
    so the types are available at runtime. VSCode or isolated static analyzers that
    open this file alone may report "Unable to find type" for:
        DLPaCBaseObject, DLPaCCondition, DLPaCAction
    This is expected in isolation and safe to ignore.

    To assist ad‑hoc editing (optional lightweight self-priming) we attempt to
    dot-source prerequisite class files only if we detect a VSCode session AND
    the types are missing. This has no effect during normal module import.

    PSScriptAnalyzer suppressions (comment-style) for editor noise:
      # PSScriptAnalyzer SuppressMessage - TypeResolution(DLPaCBaseObject)
      # PSScriptAnalyzer SuppressMessage - TypeResolution(DLPaCCondition)
      # PSScriptAnalyzer SuppressMessage - TypeResolution(DLPaCAction)
#>

if ($env:VSCODE_PID -and -not ("DLPaCBaseObject" -as [type])) {
    try {
        $ruleFileDir = Split-Path -Parent $PSCommandPath
        $classesDir  = Split-Path -Parent $ruleFileDir
        $basePath    = Join-Path $classesDir 'BaseClass.ps1'
        $condPath    = Join-Path $classesDir 'Condition.ps1'
        $actPath     = Join-Path $classesDir 'Action.ps1'
        foreach ($dep in @($basePath,$condPath,$actPath)) {
            if (Test-Path $dep) { . $dep }
        }
    } catch {
        Write-Verbose "Rule.ps1 self-priming of prerequisite classes failed: $_"
    }
}

class DLPaCRule : DLPaCBaseObject {
    [string] $PolicyName
    [System.Collections.ArrayList] $Conditions
    [System.Collections.ArrayList] $Actions
    
    DLPaCRule() : base() {
        $this.Conditions = [System.Collections.ArrayList]::new()
        $this.Actions = [System.Collections.ArrayList]::new()
    }
    
    DLPaCRule([string]$Name) : base($Name) {
        $this.Conditions = [System.Collections.ArrayList]::new()
        $this.Actions = [System.Collections.ArrayList]::new()
    }
    
    [void] AddCondition([DLPaCCondition]$Condition) {
        $this.Conditions.Add($Condition)
        $this.UpdateHash()
    }
    
    [void] AddAction([DLPaCAction]$Action) {
        $this.Actions.Add($Action)
        $this.UpdateHash()
    }
    
    [string] GenerateHash() {
        # Override base method to include conditions and actions in hash calculation
        $hashInput = @{
            Name = $this.Name
            PolicyName = $this.PolicyName
            Conditions = $this.Conditions | ForEach-Object { $_.ToHashtable() }
            Actions = $this.Actions | ForEach-Object { $_.ToHashtable() }
        } | ConvertTo-Json -Depth 10 -Compress
        
        $stream = [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($hashInput))
        $hashResult = Get-FileHash -InputStream $stream -Algorithm SHA256
        return $hashResult.Hash
    }
    
    [hashtable] ToHashtable() {
        $result = @{
            Name = $this.Name
            PolicyName = $this.PolicyName
            Conditions = $this.Conditions | ForEach-Object { $_.ToHashtable() }
            Actions = $this.Actions | ForEach-Object { $_.ToHashtable() }
        }
        
        if ($this.Id) {
            $result.Id = $this.Id
        }
        
        if ($this.Hash) {
            $result.Hash = $this.Hash
        }
        
        if ($this.LastModified) {
            $result.LastModified = $this.LastModified.ToString('o')
        }
        
        return $result
    }
    
    [hashtable] ToIPPSPParameters() {
        return $this.ToIPPSPParameters($false)
    }

    [hashtable] ToIPPSPParameters([bool]$ForUpdate) {
        # Convert to parameters for New-DlpComplianceRule
        $params = @{}
        
        # Add Name/Policy only for creation
        if (-not $ForUpdate) {
            $params.Name = $this.Name
            $params.Policy = $this.PolicyName
        }

        # Add advanced rule
        $params.AdvancedRule = $this.CreateAdvancedRuleJson()
        
        
        # Process actions
        foreach ($action in $this.Actions) {
            switch ($action.Type) {
                "BlockAccess" {
                    $params.BlockAccess = $true
                    
                    # According to Microsoft documentation, use GenerateIncidentReport and IncidentReportContent
                    # https://learn.microsoft.com/en-us/powershell/module/exchange/new-dlpcompliancerule?view=exchange-ps
                    if ($action.NotifyUser) {
                        $params.GenerateIncidentReport = "All"
                        $params.IncidentReportContent = @("All")
                    }
                    
                    # NotifyAdmin parameter is not supported by New-DlpComplianceRule
                    # Use GenerateIncidentReport and IncidentReportContent instead
                    # if ($action.NotifyAdmin) {
                    #     $params.NotifyAdmin = $action.NotifyAdmin
                    # }
                }
                "Encrypt" {
                    # Do not set Encrypt = $true as it conflicts with EncryptRMSTemplate
                    # According to Microsoft documentation, use EncryptRMSTemplate
                    # https://learn.microsoft.com/en-us/powershell/module/exchange/new-dlpcompliancerule?view=exchange-ps
                    if ($action.RMSTemplate) {
                        $params.EncryptRMSTemplate = $action.RMSTemplate
                    }
                    elseif ($action.EncryptionMethod) {
                        # For backward compatibility
                        $params.EncryptRMSTemplate = $action.EncryptionMethod
                    }
                }
            }
        }
        
        return $params
    }
    
    [string] CreateAdvancedRuleJson() {
        <#
            Phase 1 enhancement:
            Attempt to build AdvancedRule JSON via new AST pipeline (Convert-DlpYamlToRuleAst + DLPRuleAST).
            Fallback to legacy inline construction if:
              - AST helper not available
              - AST returns empty
              - Any exception is thrown (preserve backward compatibility)
        #>
        try {
            if (Get-Command -Name Convert-DlpYamlToRuleAst -ErrorAction SilentlyContinue) {
                $ast = Convert-DlpYamlToRuleAst -Rule $this
                if ($ast -and $ast.RootCondition.Children.Count -gt 0) {
                    return $ast.ToAdvancedRuleJson()
                }
            }
        }
        catch {
            Write-Verbose "AST-based AdvancedRule generation failed, falling back to legacy method: $_"
        }

        # Legacy (existing) method retained as fallback
        $advancedRule = @{
            Version = "1.0"
            Condition = @{
                Operator = "And"
                SubConditions = [System.Collections.ArrayList]@()
            }
        }

        foreach ($condition in $this.Conditions) {
            $subCondition = switch ($condition.Type) {
                { $_ -in @("ContentContainsPattern", "SensitiveInfoType") } {
                    @{
                        ConditionName = "ContentContainsSensitiveInformation"
                        Value = @(
                            @{
                                groups = @(
                                    @{
                                        name = "Default"
                                        Operator = "Or"
                                        sensitivetypes = @(
                                            @{
                                                name = if ($_ -eq "ContentContainsPattern") { $condition.Pattern } else { $condition.InfoType }
                                                minCount = $condition.MinCount
                                            }
                                        )
                                    }
                                )
                            }
                        )
                    }
                }
                "RecipientDomain" {
                    if ($condition.Operator -eq "NotEquals") {
                        @{
                            Operator = "Not"
                            SubConditions = @(
                                @{
                                    ConditionName = "RecipientDomainIs"
                                    Value = @($condition.Value)
                                }
                            )
                        }
                    }
                    else {
                        @{
                            ConditionName = "RecipientDomainIs"
                            Value = @($condition.Value)
                        }
                    }
                }
                "AccessScope" {
                    @{
                        ConditionName = "AccessScope"
                        Value = @($condition.Value)
                    }
                }
            }
            
            if ($subCondition) {
                [void]$advancedRule.Condition.SubConditions.Add($subCondition)
            }
        }

        return ($advancedRule | ConvertTo-Json -Depth 10)
    }

    static [DLPaCRule] FromYaml([hashtable]$YamlObject) {
        $rule = [DLPaCRule]::new($YamlObject.name)
        
        if ($YamlObject.conditions) {
            foreach ($conditionObj in $YamlObject.conditions) {
                $condition = [DLPaCCondition]::FromYaml($conditionObj)
                $rule.AddCondition($condition)
            }
        }
        
        if ($YamlObject.actions) {
            foreach ($actionObj in $YamlObject.actions) {
                $action = [DLPaCAction]::FromYaml($actionObj)
                $rule.AddAction($action)
            }
        }
        
        $rule.UpdateHash()
        return $rule
    }
}