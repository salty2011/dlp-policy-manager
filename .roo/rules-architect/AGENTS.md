# AGENTS.md

This file provides guidance to agents when working with code in this repository.

Non-obvious architecture rules (PowerShell module).

- Session boundary: all EXO connectivity must go through [PowerShell.DLPaCIPPSPAdapter](DLPaC/Classes/IPPSPAdapter.ps1:1); avoid direct ExchangeOnline cmdlets in new code.
- Class initialization order is fixed in [DLPaC/DLPaC.psm1](DLPaC/DLPaC.psm1:25). If adding classes, update $ClassFiles without breaking the BaseClass → Logger → SchemaValidator → Condition → Action → RuleAst → Rule → Policy → State → Plan → IPPSPAdapter order.
- Workspace gating: public flows hard-require an initialized workspace (guarded via $script:WorkspacePath). See precheck in [PowerShell.Test-DLPaCConfiguration()](DLPaC/Public/Test-DLPaCConfiguration.ps1:49).
- YAML normalization contract: all validate/plan paths must run the normalizer and coerce scalars to arrays before schema/logic. See [DLPaC/Private/Normalize-Keys.ps1](DLPaC/Private/Normalize-Keys.ps1:1) and array coercion in [PowerShell.Get-DLPaCPlan()](DLPaC/Public/Get-DLPaCPlan.ps1:136).
- Plan persistence: plans are timestamped under .dlpac/plans; when PlanPath is omitted, Apply auto-selects the newest plan (sorting by LastWriteTime). See [PowerShell.Invoke-DLPaCApply()](DLPaC/Public/Invoke-DLPaCApply.ps1:100).
- State mutation protocol: Acquire lock, mutate, save, then unlock; mirror patterns in [PowerShell.Invoke-DLPaCApply()](DLPaC/Public/Invoke-DLPaCApply.ps1:183) and [PowerShell.Invoke-DLPaCDestroy()](DLPaC/Public/Invoke-DLPaCDestroy.ps1:126).
- Logging strategy: use [PowerShell.DLPaCLogger](DLPaC/Classes/Logger.ps1:1). File logging is enabled during workspace init (dlpac.log). See [PowerShell.Initialize-DLPaCWorkspace()](DLPaC/Public/Initialize-DLPaCWorkspace.ps1:113).
- Offline planning: support -NoConnect, -CacheOnly, and -MaxCacheAge for local/offline diffs; respect cache freshness constraints. See [PowerShell.Get-DLPaCPlan()](DLPaC/Public/Get-DLPaCPlan.ps1:59) and [PowerShell.Get-DLPaCPlan()](DLPaC/Public/Get-DLPaCPlan.ps1:62).
- Module lifecycle: On module unload, EXO is disconnected; avoid persisting external sessions. See OnRemove in [DLPaC/DLPaC.psm1](DLPaC/DLPaC.psm1:90).
- Roadmap vs current: docs include forward-looking AST helpers; treat [docs/DLPaC-Enhanced-Schema-Design.md](docs/DLPaC-Enhanced-Schema-Design.md) as a roadmap where code does not yet implement helpers.