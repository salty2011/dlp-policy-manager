using namespace System.Collections.Generic
# Test script for analyzing DLP policy comparison behavior

# Import required modules
Import-Module powershell-yaml
Import-Module ./DLPaC/DLPaC.psd1 -Force

# Function to create centered title headers
function Write-CenteredTitle {
    param (
        [string]$Title,
        [int]$TotalWidth = 126  # Total width including borders
    )
    
    # Calculate padding for perfect centering
    # The -2 accounts for the left and right border characters
    $contentWidth = $TotalWidth - 2
    $padding = [Math]::Floor(($contentWidth - $Title.Length) / 2)
    $rightPadding = $contentWidth - $Title.Length - $padding
    
    # Title with borders
    $topBorder = $TableChars.TopLeft + ($TableChars.Horizontal * $contentWidth) + $TableChars.TopRight
    $centeredTitle = $TableChars.Vertical + (' ' * $padding) + $Title + (' ' * $rightPadding) + $TableChars.Vertical
    $bottomBorder = $TableChars.BottomLeft + ($TableChars.Horizontal * $contentWidth) + $TableChars.BottomRight
    
    Write-Host $topBorder -ForegroundColor $TableColors.Border
    Write-Host $centeredTitle -ForegroundColor $TableColors.Header
    Write-Host $bottomBorder -ForegroundColor $TableColors.Border
}

function Write-SectionTitle {
    param (
        [string]$Title,
        [int]$TotalWidth = 126  # Total width including borders
    )
    
    # Calculate padding for perfect centering
    # The -2 accounts for the left and right border characters
    $contentWidth = $TotalWidth - 2
    $padding = [Math]::Floor(($contentWidth - $Title.Length) / 2)
    $rightPadding = $contentWidth - $Title.Length - $padding
    
    # Section title with borders (using Tee characters)
    $topBorder = $TableChars.TopLeft + ($TableChars.Horizontal * $contentWidth) + $TableChars.TopRight
    $centeredTitle = $TableChars.Vertical + (' ' * $padding) + $Title + (' ' * $rightPadding) + $TableChars.Vertical
    $bottomBorder = $TableChars.TeeLeft + ($TableChars.Horizontal * $contentWidth) + $TableChars.TeeRight
    
    Write-Host $topBorder -ForegroundColor $TableColors.Border
    Write-Host $centeredTitle -ForegroundColor $TableColors.Header
    Write-Host $bottomBorder -ForegroundColor $TableColors.Border
}

# Get the classes loaded first
. (Join-Path $PSScriptRoot "DLPaC/Classes/BaseClass.ps1")
. (Join-Path $PSScriptRoot "DLPaC/Classes/Condition.ps1")
. (Join-Path $PSScriptRoot "DLPaC/Classes/Action.ps1")
. (Join-Path $PSScriptRoot "DLPaC/Classes/Rule.ps1")
. (Join-Path $PSScriptRoot "DLPaC/Classes/Policy.ps1")

# Table formatting
$script:TableChars = @{
    TopLeft     = "╔"
    TopRight    = "╗"
    BottomLeft  = "╚"
    BottomRight = "╝"
    Horizontal  = "═"
    Vertical    = "║"
    TeeLeft     = "╠"
    TeeRight    = "╣"
    TeeTop      = "╦"
    TeeBottom   = "╩"
    Cross       = "╬"
}

$script:TableColors = @{
    Border = 'Cyan'
    Header = 'Yellow'
}

# Table border helpers (must be defined before use)
function Write-TableBottomBorder {
    param (
        [int[]]$ColumnWidths
    )
    $line = $TableChars.BottomLeft
    for ($i = 0; $i -lt $ColumnWidths.Count; $i++) {
        $line += $TableChars.Horizontal * $ColumnWidths[$i]
        $line += if ($i -lt $ColumnWidths.Count - 1) { $TableChars.TeeBottom } else { $TableChars.BottomRight }
    }
    Write-Host $line -ForegroundColor $TableColors.Border
}

function Write-TableHeader {
    param (
        [string[]]$Headers,
        [int[]]$ColumnWidths
    )
    
    # Draw header content and separator
    $headerLine = $TableChars.Vertical
    for ($i = 0; $i -lt $Headers.Count; $i++) {
        $content = "$($Headers[$i])".PadRight($ColumnWidths[$i])
        $headerLine += $content + $TableChars.Vertical
    }
    Write-Host $headerLine -ForegroundColor $TableColors.Header
    
    # Draw header separator with crosses
    $line = $TableChars.TeeLeft
    for ($i = 0; $i -lt $Headers.Count; $i++) {
        $line += $TableChars.Horizontal * $ColumnWidths[$i]
        $line += if ($i -lt $Headers.Count - 1) { $TableChars.Cross } else { $TableChars.TeeRight }
    }
    Write-Host $line -ForegroundColor $TableColors.Border
}

function Write-TableRow {
    param (
        [string[]]$Columns,
        [int[]]$ColumnWidths,
        [switch]$IsLastRow
    )

    # Draw content row
    $line = $TableChars.Vertical
    for ($i = 0; $i -lt $Columns.Count; $i++) {
        $content = if ($i -eq $Columns.Count - 1 -and $Columns[$i] -match '^[✅❌]$') {
            $symbol = $Columns[$i]
            $pad = $ColumnWidths[$i]
            $left = [Math]::Floor(($pad - 1) / 2)
            $right = $pad - $left - 2
            (' ' * $left) + $symbol + (' ' * $right)
        } else {
            if ([string]::IsNullOrWhiteSpace($Columns[$i])) {
                " ".PadRight($ColumnWidths[$i])
            } else {
                "$($Columns[$i])".PadRight($ColumnWidths[$i])
            }
        }
        $line += $content + $TableChars.Vertical
    }
    Write-Host $line -ForegroundColor White

    # Draw bottom border if last row
    if ($IsLastRow) {
        Write-TableBottomBorder -ColumnWidths $ColumnWidths
    }
}

# Ensure all required modules are loaded
Import-Module powershell-yaml
Import-Module ./DLPaC/DLPaC.psd1 -Force

function Compare-PolicyObjects {
    param(
        [string]$TestName,
        $DefinedPolicy, # Removed type constraint
        $AppliedPolicy,
        $AppliedRules
    )

    Write-CenteredTitle -Title $DefinedPolicy.Name

    Write-Host "## Policy"
    Write-SectionTitle -Title "Scope"
    # Define standard column widths for all tables
    $columnWidths = @(20, 45, 45, 11)  # Total width 121 + 5 borders = 126
    Write-TableHeader -Headers @("Service", "Desired", "Active", "Result") -ColumnWidths $columnWidths

    $scopeMapping = @{
        'Exchange' = 'ExchangeLocation'
        'SharePoint' = 'SharePointLocation'
        'OneDrive' = 'OneDriveLocation'
        'Teams' = 'TeamsLocation'
        'Devices' = 'EndpointDlpLocation'
    }

    foreach ($key in $DefinedPolicy.Scope.Keys) {
        $definedValue = $DefinedPolicy.Scope[$key]
        $appliedProp = $scopeMapping[$key]
        
        # Handle array comparison for scope
        $isAppliedAll = if ($AppliedPolicy.$appliedProp) {
            $appliedValue = $AppliedPolicy.$appliedProp
            
            # Handle "All" case first
            if ("$appliedValue" -in @("{All}", "All")) {
                $true
            }
            elseif ($appliedValue -is [array] -and $definedValue -is [array]) {
                # Compare arrays ignoring order
                $diff = Compare-Object -ReferenceObject $appliedValue -DifferenceObject $definedValue
                # Silent comparison
                -not $diff
            } else {
                $false
            }
        } else {
            $false
        }
        
        # Convert YAML scope value for comparison
        $isDefinedAll = if ("$definedValue" -in @("All", "{All}")) {
            $true
        }
        elseif ($definedValue -is [array] -and $AppliedPolicy.$appliedProp -is [array]) {
            # Already handled in isAppliedAll comparison
            $true
        } else {
            $false
        }

        # Format display values
        $definedDisplay = if ($definedValue -is [array]) { $definedValue -join ', ' } else { $definedValue }
        $appliedDisplay = $AppliedPolicy.$appliedProp
        $status = if ($isDefinedAll -eq $isAppliedAll) { "✅" } else { "❌" }

        # Output table row
        $appliedStr = [string]$appliedDisplay -replace '^$',' ' # Handle empty values
        $isLastScopeKey = $key -eq @($DefinedPolicy.Scope.Keys)[-1]
        Write-TableRow -Columns @($key, $definedDisplay, $appliedStr, $status) -ColumnWidths $columnWidths -IsLastRow:$isLastScopeKey
    }

    # Compare rules section
    if ($null -eq $DefinedPolicy.Rules -or @($DefinedPolicy.Rules).Count -eq 0) {
        Write-Host "  No rules defined in policy." -ForegroundColor Yellow
        return
    }
    foreach ($definedRule in $DefinedPolicy.Rules) {
        $appliedRule = $AppliedRules | Where-Object { $_.Name -eq $definedRule.Name }
        if ($appliedRule) {
            Write-Host "## Rules"
            Write-SectionTitle -Title "Conditions"
            Write-TableHeader -Headers @("Type", "Desired", "Active", "Result") -ColumnWidths $columnWidths
            $conditions = @($definedRule.Conditions)
            if ($null -ne $definedRule.Conditions -and $conditions.Count -gt 0) {
                foreach ($condition in $conditions) {
                    $isLast = ($condition -eq $conditions[-1])
                    #Write-Host "DEBUG: Processing condition type: $($condition.Type)" -ForegroundColor Yellow
                    switch ($condition.Type) {
                        "SensitiveInfoType" {
                            #Write-Host "DEBUG: Inside SensitiveInfoType case" -ForegroundColor Yellow
                            $appliedSensitiveInfo = @(if ($appliedRule.AdvancedRule) {
                                $advancedRule = $appliedRule.AdvancedRule | ConvertFrom-Json
                                $advancedRule.Condition.SubConditions |
                                    Where-Object { $_.ConditionName -eq "ContentContainsSensitiveInformation" } |
                                    ForEach-Object { $_.Value.groups.sensitivetypes }
                            } else {
                                $appliedRule.ContentContainsSensitiveInformation
                            })

                            $definedInfo = @{
                                name = $condition.InfoType
                                minCount = [int]$condition.MinCount
                            }

                            $matchingInfo = $appliedSensitiveInfo | Where-Object {
                                ($_.name -eq $definedInfo.name -or
                                 $_.Name -eq $definedInfo.name) -and
                                ($_.minCount -eq $definedInfo.minCount -or
                                 $_.MinCount -eq $definedInfo.minCount)
                            }

                            $status = if ($matchingInfo) { "✅" } else { "❌" }
                            $desiredStr = "Name=$($definedInfo.name), Count=$($definedInfo.minCount)"
                            $activeStr = if ($appliedSensitiveInfo) {
                                "Name=$($appliedSensitiveInfo.name), Count=$($appliedSensitiveInfo.minCount)"
                            } else {
                                "Not found"
                            }
                            Write-TableRow -Columns @("SensitiveInfoType", $desiredStr, $activeStr, $status) -ColumnWidths $columnWidths -IsLastRow:$isLast
                        }
                        "RecipientDomain" {
                            $appliedValue = if ($condition.Operator -eq "Equals") {
                                $appliedRule.RecipientDomainIs
                            } else {
                                $appliedRule.RecipientDomainIsNot
                            }
                            
                            $status = if ($condition.Value -eq $appliedValue) { "✅" } else { "❌" }
                            Write-TableRow -Columns @("RecipientDomain", $condition.Value, $appliedValue, $status) -ColumnWidths $columnWidths -IsLastRow:$isLast
                        }
                        "AccessScope" {
                            $status = if ($condition.Value -eq $appliedRule.AccessScope) { "✅" } else { "❌" }
                            Write-TableRow -Columns @("AccessScope", $condition.Value, $appliedRule.AccessScope, $status) -ColumnWidths $columnWidths -IsLastRow:$isLast
                        }
                    }
                }
            } else {
                Write-TableRow -Columns @("No conditions", "", "", "") -ColumnWidths $columnWidths -IsLastRow:$true
            }
            
            # Compare actions
            Write-SectionTitle -Title "Actions"
            Write-TableHeader -Headers @("Type", "Desired", "Active", "Result") -ColumnWidths $columnWidths
            $actions = @($definedRule.Actions)
            if ($null -ne $actions -and $actions.Count -gt 0) {
                #Write-Host "DEBUG: Starting actions loop" -ForegroundColor Yellow
                foreach ($action in $actions) {
                    #Write-Host "DEBUG: Processing action type: $($action.Type)" -ForegroundColor Yellow
                    switch ($action.Type) {
                        "BlockAccess" {
                            #Write-Host "DEBUG: Inside BlockAccess case" -ForegroundColor Yellow
                            $status = if ($action.NotifyUser -eq $appliedRule.NotifyUser -and
                                        $action.NotifyAdmin -eq $appliedRule.NotifyAdmin) {
                                "✅"
                            } else {
                                "❌"
                            }

                            $desired = "NotifyUser=$($action.NotifyUser), NotifyAdmin=$($action.NotifyAdmin)"
                            $active = "NotifyUser=$($appliedRule.NotifyUser), NotifyAdmin=$($appliedRule.NotifyAdmin)"
                            Write-TableRow -Columns @("BlockAccess", $desired, $active, $status) -ColumnWidths $columnWidths -IsLastRow:($action -eq $actions[-1])
                        }
                        "Encrypt" {
                            #Write-Host "DEBUG: Inside Encrypt case" -ForegroundColor Yellow
                            $definedEncryption = $action.EncryptionMethod ?? "Encrypt"
                            $appliedEncryption = $appliedRule.EncryptRMSTemplate ?? "Encrypt"
                            $status = if ($definedEncryption -eq $appliedEncryption) { "✅" } else { "❌" }
                            Write-TableRow -Columns @("Encrypt", $definedEncryption, $appliedEncryption, $status) -ColumnWidths $columnWidths -IsLastRow:($action -eq $actions[-1])
                        }
                    }
                }
            }
            else {
                Write-TableRow -Columns @("No actions", "", "", "") -ColumnWidths $columnWidths -IsLastRow
            }
        }
        else {
            Write-Host "  Rule $($definedRule.Name) defined but not found in applied policy" -ForegroundColor Red
        }
    }

    # Check for extra applied rules not in definition
    foreach ($appliedRule in $AppliedRules) {
        $definedRule = $DefinedPolicy.Rules | Where-Object { $_.Name -eq $appliedRule.Name }
        if (-not $definedRule) {
            Write-Host "  Rule $($appliedRule.Name) exists in applied policy but not in definition" -ForegroundColor Yellow
        }
    }
    # Debug logging
    # Write-Host "DEBUG: Reached end of Compare-PolicyObjects function" -ForegroundColor Yellow
}

function Test-PolicyComparison {
    param(
        [string]$PolicyYamlPath,
        [string]$PolicyName
    )

    Write-Host "Starting policy comparison test"
    Write-Host "YAML Path: $PolicyYamlPath"
    Write-Host "Policy Name: $PolicyName"

    try {
        # Import the defined policy from YAML
        Write-Host "`nImporting policy from YAML..." -ForegroundColor Cyan
        $yamlContent = Get-Content -Path $PolicyYamlPath -Raw
        $yamlObj = $yamlContent | ConvertFrom-Yaml
        
        # Assume the YAML has a 'policies' array, take the first policy for comparison
        $policyDef = $yamlObj.policies[0]
        
        # Map YAML to DLPaCPolicy object
        $definedPolicy = [DLPaCPolicy]::new($policyDef.name)
        $definedPolicy.Description = $policyDef.description
        $definedPolicy.Mode = $policyDef.mode
        $definedPolicy.Priority = $policyDef.priority
        $definedPolicy.Scope = $policyDef.scope
        
        # Add rules from YAML
        foreach ($ruleDef in $policyDef.rules) {
            $rule = [DLPaCRule]::new($ruleDef.name)
            # Add conditions
            foreach ($condDef in $ruleDef.conditions) {
                $cond = [DLPaCCondition]::new($condDef.type)
                if ($condDef.infoType) { $cond.InfoType = $condDef.infoType }
                if ($condDef.minCount) { $cond.MinCount = $condDef.minCount }
                if ($condDef.operator) { $cond.Operator = $condDef.operator }
                if ($condDef.value) { $cond.Value = $condDef.value }
                if ($condDef.pattern) { $cond.Pattern = $condDef.pattern }
                $rule.AddCondition($cond)
            }
            # Add actions
            foreach ($actDef in $ruleDef.actions) {
                $act = [DLPaCAction]::new($actDef.type)
                if ($actDef.notifyUser) { $act.NotifyUser = $actDef.notifyUser }
                if ($actDef.notifyAdmin) { $act.NotifyAdmin = $actDef.notifyAdmin }
                # Handle both rmsTemplate and encryptionMethod for encryption actions
                if ($actDef.type -eq "Encrypt") {
                    if ($actDef.rmsTemplate) {
                        $act.EncryptionMethod = $actDef.rmsTemplate
                    }
                    elseif ($actDef.encryptionMethod) {
                        $act.EncryptionMethod = $actDef.encryptionMethod
                    }
                }
                $rule.AddAction($act)
            }
            $definedPolicy.AddRule($rule)
        }
        
        # Get current policy state from tenant
        Write-Host "Retrieving applied policy from tenant..." -ForegroundColor Cyan
        $appliedPolicy = Get-DlpCompliancePolicy -Identity $PolicyName
        $appliedRules = Get-DlpComplianceRule -Policy $PolicyName
        
        if ($appliedPolicy) {
            Compare-PolicyObjects `
                -TestName "Comparing Defined Policy (YAML) vs Applied Policy (Tenant)" `
                -DefinedPolicy $definedPolicy `
                -AppliedPolicy $appliedPolicy `
                -AppliedRules $appliedRules
        } else {
            Write-Host "Policy '$PolicyName' not found in tenant" -ForegroundColor Red
        }

    } catch {
        Write-Host "Error during policy comparison test: $_" -ForegroundColor Red
    }
}

# Example usage:
Test-PolicyComparison -PolicyYamlPath "Test/configs/example-policy.yaml" -PolicyName "Financial SuperData Protection"