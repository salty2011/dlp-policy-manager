# AGENTS.md

This file provides guidance to agents when working with code in this repository.

Non-obvious coding rules (PowerShell module).

- Public cmdlets auto-export: any .ps1 in [DLPaC/Public/](DLPaC/Public/) is exported via [PowerShell.Export-ModuleMember()](DLPaC/DLPaC.psm1:105). Do not add Export-ModuleMember manually.
- Class load order is enforced in [PowerShell.Module init](DLPaC/DLPaC.psm1:25). If you add classes, update $ClassFiles respecting existing order (BaseClass → Logger → SchemaValidator → Condition → Action → RuleAst → Rule → Policy → State → Plan → IPPSPAdapter).
- Do not call ExchangeOnline cmdlets directly; use [PowerShell.DLPaCIPPSPAdapter](DLPaC/Classes/IPPSPAdapter.ps1:1) for Connect/Disconnect and operations.
- Always guard public cmdlets with workspace checks; throw if [$script:WorkspacePath](DLPaC/DLPaC.psm1:13) is null (see [PowerShell.Test-DLPaCConfiguration()](DLPaC/Public/Test-DLPaCConfiguration.ps1:49)).
- Normalize YAML and coerce arrays before schema/logic: use [PowerShell.Normalize-DLPaCKeys()](DLPaC/Private/Normalize-Keys.ps1:1) and then ensure policies/rules/conditions/actions are arrays (see [PowerShell.Get-DLPaCPlan()](DLPaC/Public/Get-DLPaCPlan.ps1:136) and [PowerShell.Test-DLPaCConfiguration()](DLPaC/Public/Test-DLPaCConfiguration.ps1:135)).
- Use [PowerShell.DLPaCLogger](DLPaC/Classes/Logger.ps1:1); avoid Write-Host in cmdlets. Tests may use Write-Host (see [Test/Test Scripts/Test-DLPaC-Workflow.ps1](Test/Test Scripts/Test-DLPaC-Workflow.ps1:11)).
- State mutations must lock/unlock via [PowerShell.DLPaCState methods](DLPaC/Classes/State.ps1:1); follow patterns in [PowerShell.Invoke-DLPaCApply()](DLPaC/Public/Invoke-DLPaCApply.ps1:182) and [PowerShell.Invoke-DLPaCDestroy()](DLPaC/Public/Invoke-DLPaCDestroy.ps1:126).
- Plans are timestamped under .dlpac/plans and latest is auto-picked when PlanPath is omitted (see [PowerShell.Invoke-DLPaCApply()](DLPaC/Public/Invoke-DLPaCApply.ps1:92)).
- On module unload, Exchange Online is disconnected (see [PowerShell.Module OnRemove](DLPaC/DLPaC.psm1:90)). Avoid creating separate persistent sessions.