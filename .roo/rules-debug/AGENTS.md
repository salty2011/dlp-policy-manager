# AGENTS.md

This file provides guidance to agents when working with code in this repository.

Non-obvious debug rules (PowerShell module).

- Reload cycle: remove then import to pick up edits (see [Test/Test Scripts/Test-DLPaC-Workflow.ps1](Test/Test Scripts/Test-DLPaC-Workflow.ps1:11)).
- Workspace precheck: many cmdlets hard-fail if the workspace isn’t initialized (see [PowerShell.Test-DLPaCConfiguration()](DLPaC/Public/Test-DLPaCConfiguration.ps1:49)).
- File logs are enabled during workspace init; primary log at .dlpac/logs/dlpac.log (see [PowerShell.Initialize-DLPaCWorkspace()](DLPaC/Public/Initialize-DLPaCWorkspace.ps1:107) and [PowerShell.Initialize-DLPaCWorkspace()](DLPaC/Public/Initialize-DLPaCWorkspace.ps1:113)).
- Classifier cache: validation warns if cache missing; run Initialize-DLPaCWorkspace to populate (see [PowerShell.Test-DLPaCConfiguration()](DLPaC/Public/Test-DLPaCConfiguration.ps1:61)).
- Offline planning for repros: use -CacheOnly and/or -NoConnect (see [PowerShell.Get-DLPaCPlan()](DLPaC/Public/Get-DLPaCPlan.ps1:59) and [PowerShell.Get-DLPaCPlan()](DLPaC/Public/Get-DLPaCPlan.ps1:62)).
- Apply requires live EXO session; connection failures surface early (see [PowerShell.Invoke-DLPaCApply()](DLPaC/Public/Invoke-DLPaCApply.ps1:125)).
- State file contention: Apply/Destroy lock/unlock state; clear stuck locks by letting the cmdlet reach its finally path (see [PowerShell.Invoke-DLPaCApply()](DLPaC/Public/Invoke-DLPaCApply.ps1:182) and [PowerShell.Invoke-DLPaCDestroy()](DLPaC/Public/Invoke-DLPaCDestroy.ps1:126)).
- Module unload auto-disconnects EXO; spurious sessions usually clear on Remove-Module (see [PowerShell.Module OnRemove](DLPaC/DLPaC.psm1:90)).
- Prefer logger over Write-Host inside cmdlets; Write-Host only in test scripts (see [DLPaC/Classes/Logger.ps1](DLPaC/Classes/Logger.ps1:1) and [Test/Test Scripts/Test-DLPaC-Workflow.ps1](Test/Test Scripts/Test-DLPaC-Workflow.ps1:26)).