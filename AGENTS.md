# AGENTS.md

This file provides guidance to agents when working with code in this repository.

Non-obvious, project-specific notes (PowerShell module). Avoid generic guidance.

- Stack
  - PowerShell module with RequiredModules in [DLPaC/DLPaC.psd1](DLPaC/DLPaC.psd1); runtime must have ExchangeOnlineManagement and powershell-yaml.
  - Public cmdlets are defined in [DLPaC/Public/](DLPaC/Public/) and auto-exported via [PowerShell.Export-ModuleMember()](DLPaC/DLPaC.psm1:105).

- Workspace prerequisites
  - Always initialize workspace before validate/plan/apply: [PowerShell.Initialize-DLPaCWorkspace()](DLPaC/Public/Initialize-DLPaCWorkspace.ps1:1).
  - Initialization creates .dlpac/ and caches classifiers; many commands rely on that cache (see [DLPaC/Public/Test-DLPaCConfiguration.ps1](DLPaC/Public/Test-DLPaCConfiguration.ps1:1)).

- Build/Lint/Test commands
  - Build: none (module loads directly via [DLPaC/DLPaC.psd1](DLPaC/DLPaC.psd1)).
  - Import module: pwsh -NoProfile -Command "Import-Module ./DLPaC/DLPaC.psd1 -Force"
  - Full workflow test: pwsh -NoProfile -File [Test/Test Scripts/Test-DLPaC-Workflow.ps1](Test/Test Scripts/Test-DLPaC-Workflow.ps1)
  - Single validation test (schema): pwsh -NoProfile -File [Test/Test Scripts/Test-SchemaValidation.ps1](Test/Test Scripts/Test-SchemaValidation.ps1)
  - Single validation test (yaml): pwsh -NoProfile -File [Test/Test Scripts/Test-YamlValidation.ps1](Test/Test Scripts/Test-YamlValidation.ps1)

- Planning nuances
  - Offline planning supported: [PowerShell.Get-DLPaCPlan()](DLPaC/Public/Get-DLPaCPlan.ps1:1) accepts -CacheOnly and -MaxCacheAge; use -NoConnect for local-only parsing.
  - Plans are timestamped into .dlpac/plans; latest is auto-picked by [PowerShell.Invoke-DLPaCApply()](DLPaC/Public/Invoke-DLPaCApply.ps1:1).

- YAML ingestion rules
  - Keys are normalized and non-array nodes are coerced to arrays during parse in plan/validate paths; do not assume singular types for policies/rules/conditions/actions.
  - Always pass YAML through the normalizer in [DLPaC/Private/Normalize-Keys.ps1](DLPaC/Private/Normalize-Keys.ps1) before schema or logic work.

- State and safety
  - Apply/Destroy lock the state file before mutations and unlock after save; mimic this pattern if extending flows (see [PowerShell.Invoke-DLPaCApply()](DLPaC/Public/Invoke-DLPaCApply.ps1:1) and [PowerShell.Invoke-DLPaCDestroy()](DLPaC/Public/Invoke-DLPaCDestroy.ps1:1)).
  - Use the module logger instead of Write-Host inside cmdlets; tests may use Write-Host, but cmdlets use [DLPaC/Classes/Logger.ps1](DLPaC/Classes/Logger.ps1).

- Connectivity
  - Cmdlets use the IPPSP adapter in [DLPaC/Classes/IPPSPAdapter.ps1](DLPaC/Classes/IPPSPAdapter.ps1) to manage a single session; do not call ExchangeOnline cmdlets directly from new code.