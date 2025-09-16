# DLPaC - DLP-as-Code for Microsoft 365

DLPaC (DLP-as-Code) is a PowerShell module that enables infrastructure-as-code management of Microsoft 365 Data Loss Prevention (DLP) policies. It follows a Terraform-like workflow, allowing you to define, plan, apply, and destroy DLP policies using YAML configuration files.

## Features

- **Infrastructure-as-Code**: Define your DLP policies as YAML files
- **Plan-Apply Workflow**: Preview changes before applying them
- **State Management**: Track the state of your DLP policies
- **Idempotent Operations**: Apply the same configuration multiple times without side effects
- **Import Existing**: Import existing DLP policies from your tenant
- **Validation**: Validate your YAML configurations against a schema

## Installation

### Prerequisites

- PowerShell 5.1 or higher
- ExchangeOnlineManagement module 3.0.0 or higher
- powershell-yaml module 0.4.2 or higher


### Manual Installation

1. Clone the repository:
   ```powershell
   git clone https://github.com/DLPaC/DLPaC.git
   ```

2. Import the module:
   ```powershell
   Import-Module ./DLPaC/DLPaC.psd1
   ```

## Quick Start

### 1. Initialize a Workspace

```powershell
Initialize-DLPaCWorkspace -Path "./dlp-workspace"
```

### 2. Create a Policy Configuration

Create a YAML file in the `configs` directory of your workspace:

```yaml
# financial-data-policy.yaml
policies:
  - name: "Financial Data Protection"
    mode: "Enable"  # Enable, Test, or Disable
    priority: 1
    description: "Protects financial data from unauthorized sharing"
    
    # Policy scope
    scope:
      exchange: true
      sharepoint: true
      onedrive: true
      teams: true
      devices: false
      
    # Policy rules
    rules:
      - name: "Credit Card Rule"
        conditions:
          - type: "ContentContainsPattern"
            pattern: "CreditCardNumber"
            minCount: 1
            
          - type: "RecipientDomain"
            operator: "NotEquals"
            value: "contoso.com"
            
        actions:
          - type: "BlockAccess"
            notifyUser: true
            notifyAdmin: true
            
      - name: "Banking Information Rule"
        conditions:
          - type: "SensitiveInfoType"
            infoType: "BankAccountNumber"
            minCount: 1
            
        actions:
          - type: "Encrypt"
            encryptionMethod: "Office365Message"
```

### 3. Validate Your Configuration

```powershell
Test-DLPaCConfiguration -Path "./dlp-workspace/configs/financial-data-policy.yaml"
```

### 4. Generate a Plan

```powershell
Get-DLPaCPlan -ConfigPath "./dlp-workspace/configs" -Detailed
```

### 5. Apply the Plan

```powershell
Invoke-DLPaCApply
```

### 6. Destroy Resources (When Needed)

```powershell
Invoke-DLPaCDestroy -ConfigPath "./dlp-workspace/configs/financial-data-policy.yaml"
```

## Workflow Guide

DLPaC follows a Terraform-like workflow for managing DLP policies. Here's a detailed guide to the workflow:

### 1. Initialize Workspace

The first step is to initialize a workspace:

```powershell
Initialize-DLPaCWorkspace -Path "./dlp-workspace" -TenantName "contoso.onmicrosoft.com" -Environment "production"
```

This creates:
- A `.dlpac` directory for state, plans, and logs
- A `configs` directory for your YAML policy files
- An example policy file
- A `.gitignore` file

### 2. Define Policies

Create or edit YAML files in the `configs` directory to define your DLP policies. You can:
- Edit the example policy
- Create new policy files
- Import existing policies from your tenant

### 3. Validate Configurations

Before applying changes, validate your configurations:

```powershell
Test-DLPaCConfiguration -Path "./dlp-workspace/configs"
```

This checks:
- YAML syntax
- Schema compliance
- Logical consistency

### 4. Generate a Plan

Generate a plan to see what changes will be made:

```powershell
Get-DLPaCPlan -ConfigPath "./dlp-workspace/configs" -Detailed
```

The plan shows:
- Policies to be created
- Policies to be updated
- Policies to be deleted
- Rules to be created, updated, or deleted

### 5. Apply Changes

Apply the changes to your Microsoft 365 tenant:

```powershell
Invoke-DLPaCApply
```

This:
- Connects to your Microsoft 365 tenant
- Makes the changes outlined in the plan
- Updates the state file

### 6. Import Existing Policies (Optional)

If you have existing policies in your tenant, you can import them:

```powershell
Import-DLPaCExisting -OutputPath "./dlp-workspace/configs"
```

This:
- Retrieves policies from your tenant
- Generates YAML files
- Updates the state file

### 7. Destroy Policies (When Needed)

When you need to remove policies:

```powershell
Invoke-DLPaCDestroy -ConfigPath "./dlp-workspace/configs/policy-to-remove.yaml"
```

This:
- Removes the specified policies from your tenant
- Updates the state file

## YAML Configuration Format

DLPaC uses YAML files to define DLP policies. Here's the basic structure:

```yaml
policies:
  - name: "Policy Name"
    mode: "Enable"  # Enable, Test, or Disable
    priority: 1
    description: "Policy description"
    
    # Policy scope
    scope:
      exchange: true|false
      sharepoint: true|false
      onedrive: true|false
      teams: true|false
      devices: true|false
      
    # Policy rules
    rules:
      - name: "Rule Name"
        conditions:
          - type: "ConditionType"
            # Condition-specific properties
            
        actions:
          - type: "ActionType"
            # Action-specific properties
```

### Example Policies

#### Financial Data Policy

```yaml
policies:
  - name: "Financial Data Protection"
    mode: "Enable"
    priority: 1
    description: "Protects financial data from unauthorized sharing"
    scope:
      exchange: true
      sharepoint: true
      onedrive: true
      teams: true
      devices: false
    rules:
      - name: "Credit Card Rule"
        conditions:
          - type: "ContentContainsPattern"
            pattern: "CreditCardNumber"
            minCount: 1
        actions:
          - type: "BlockAccess"
            notifyUser: true
            notifyAdmin: true
```

#### PII Protection Policy

```yaml
policies:
  - name: "PII Protection Policy"
    mode: "Enable"
    priority: 2
    description: "Protects personally identifiable information from unauthorized sharing"
    scope:
      exchange: true
      sharepoint: true
      onedrive: true
      teams: true
      devices: true
    rules:
      - name: "SSN Protection Rule"
        conditions:
          - type: "SensitiveInfoType"
            infoType: "U.S. Social Security Number (SSN)"
            minCount: 1
        actions:
          - type: "BlockAccess"
            notifyUser: true
            notifyAdmin: true
```

## Command Reference

### Get-DLPaCClassifiers

Retrieves available classifiers for DLP policies.

```powershell
Get-DLPaCClassifiers
```

### Initialize-DLPaCWorkspace

Creates a new DLPaC workspace.

```powershell
Initialize-DLPaCWorkspace -Path <string> [-Force]
```

### Test-DLPaCConfiguration

Validates DLP policy configuration files against the schema.

```powershell
Test-DLPaCConfiguration -Path <string> [-Detailed]
```

### Get-DLPaCPlan

Generates a plan of changes to be applied to DLP policies.

```powershell
Get-DLPaCPlan [-ConfigPath <string>] [-OutputPath <string>] [-Detailed] [-NoConnect]
```

### Invoke-DLPaCApply

Applies the changes specified in the plan.

```powershell
Invoke-DLPaCApply [-PlanPath <string>] [-AutoApprove]
```

### Invoke-DLPaCDestroy

Removes DLP policies defined in the configuration.

```powershell
Invoke-DLPaCDestroy [-ConfigPath <string>] [-AutoApprove]
```

### Import-DLPaCExisting

Imports existing DLP policies from the Microsoft 365 tenant.

```powershell
Import-DLPaCExisting [-OutputPath <string>] [-PolicyName <string>] [-Force]
```

## State Management

DLPaC maintains a state file in the `.dlpac/state` directory of your workspace. This file tracks the current state of your DLP policies and is used to determine what changes need to be made when you apply a new configuration.

The state file is automatically updated when you apply changes, but you should not edit it manually.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. Refer to `DLPaC-Architecture.md` for an overview of the project's design.

## Troubleshooting

### Schema Validation Errors

If you encounter schema validation errors when running `Test-DLPaCConfiguration`, check the following:

1. **YAML Syntax**: Ensure your YAML file has proper syntax. Common issues include:
   - Incorrect indentation
   - Missing or extra spaces
   - Unquoted strings that contain special characters

2. **Required Fields**: Make sure all required fields are present:
   - Each policy must have `name`, `mode`, and `rules`
   - Each rule must have `name`, `conditions`, and `actions`
   - Each condition must have `type` and type-specific required fields:
     - `ContentContainsPattern` requires `pattern`
     - `SensitiveInfoType` requires `infoType`
     - `RecipientDomain` requires `operator` and `value`
     - `AccessScope` requires `value`
   - Each action must have `type` and type-specific required fields:
     - `Encrypt` requires `encryptionMethod`

3. **Field Values**: Ensure field values match the expected types and constraints:
   - `mode` must be one of: "Enable", "Test", "Disable"
   - `priority` must be a non-negative integer
   - Boolean values must be `true` or `false` (not strings)

4. **Module Version**: Ensure you're using the latest version of the powershell-yaml module:
   ```powershell
   Install-Module -Name powershell-yaml -Force
   ```

5. **Verbose Output**: Run the validation with verbose output for more details:
   ```powershell
   Test-DLPaCConfiguration -Path "path/to/config.yaml" -Verbose
   ```

For more detailed schema information, refer to the [policy-schema.json](DLPaC/Schemas/policy-schema.json) file.

### Debugging Scripts

Use the provided scripts for debugging YAML and schema issues:
- `Test-SchemaValidation.ps1`
- `Test-YamlValidation.ps1`

Run these scripts to validate and troubleshoot your configurations.
## Optional: Manual Session Management

For long workflows, you can avoid repeated authentication prompts by manually managing a single Exchange Online session.

- Start session once:
```PowerShell
Connect-DLPaC
```

- Run your DLPaC workflow:
```PowerShell
Initialize-DLPaCWorkspace -Path "./dlp-workspace" -TenantName "contoso.onmicrosoft.com" -Environment "production"
Get-DLPaCPlan -Path "./dlp-workspace/configs" -Detailed
Invoke-DLPaCApply -AutoApprove
# ... or cleanup:
Invoke-DLPaCDestroy -AutoApprove
```

- End session:
```PowerShell
Disconnect-DLPaC
```

Notes:
- Standalone cmdlets still auto-connect, and will auto-disconnect unless a manual session is active.
- Connect/Disconnect are idempotent; calling them multiple times is safe.

## Compatibility checks

Pre-deployment detection of unsupported action/condition/scope combinations. Runs automatically during planning via [PowerShell.Get-DLPaCPlan()](DLPaC/Public/Get-DLPaCPlan.ps1:1) and during configuration validation via [PowerShell.Test-DLPaCConfiguration()](DLPaC/Public/Test-DLPaCConfiguration.ps1:1). Findings with severity "error" abort; "warn" logs and proceeds.

### Quick start

- Initialize workspace (scaffolds overrides file):
```powershell
[PowerShell]
Initialize-DLPaCWorkspace -Path "./dlp-workspace"
```

- Edit overrides:
  - File: [.dlpac/compatibility-overrides.yaml](.dlpac/compatibility-overrides.yaml:1)

- Run validation and plan (offline-friendly):
```powershell
[PowerShell]
# Validate configs (schema + compatibility); fails on "error"
Test-DLPaCConfiguration -Path "./dlp-workspace/configs" -Detailed

# Plan without connecting; aborts on "error", persists "warn"
Get-DLPaCPlan -ConfigPath "./dlp-workspace/configs" -NoConnect -Detailed
```

### Behavior and results

- Abort-on-error: Planning and config validation stop on "error" findings.
- Findings on plan: Saved under [PowerShell.DLPaCPlan.CompatibilityFindings](DLPaC/Classes/Plan.ps1:1) in the generated plan saved to `.dlpac/plans`.

### Examples and references

- Baseline rules (module defaults): [DLPaC/Rules/compatibility-rules.yaml](DLPaC/Rules/compatibility-rules.yaml:1)
- Demo config with an incompatible Encrypt on SPO/OneDrive: [Test/configs/incompatible-encrypt-spo-od.yaml](Test/configs/incompatible-encrypt-spo-od.yaml:1)

Minimal override examples:
```yaml
[yaml]
# Disable a default rule by id (case-insensitive)
- id: "encrypt-spo-od-unsupported"
  enabled: false

# Downgrade severity to warn
- id: "encrypt-spo-od-unsupported"
  severity: "warn"
```

See the detailed design for schema, precedence, and integrations: [docs/DLPaC-Enhanced-Schema-Design.md](docs/DLPaC-Enhanced-Schema-Design.md:1)