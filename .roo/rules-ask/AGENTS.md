# AGENTS.md

This file provides guidance to agents when working with code in this repository.

Non-obvious documentation context (PowerShell module).

- Authoritative entrypoints are public cmdlets in [DLPaC/Public/](DLPaC/Public/) and auto-exported via [PowerShell.Export-ModuleMember()](DLPaC/DLPaC.psm1:105). Prefer linking to these files over README snippets.
- Workspace is mandatory for most flows; many cmdlets hard-fail if uninitialized (see precheck in [PowerShell.Test-DLPaCConfiguration()](DLPaC/Public/Test-DLPaCConfiguration.ps1:49)). Always instruct to run [PowerShell.Initialize-DLPaCWorkspace()](DLPaC/Public/Initialize-DLPaCWorkspace.ps1:1) first.
- Schema source of truth is [policy-schema.json](DLPaC/Schemas/policy-schema.json). Do not rely on README examples if they diverge.
- YAML is normalized and arrays coerced during validate/plan; users must not assume singular types for policies/rules/conditions/actions (normalizer in [DLPaC/Private/Normalize-Keys.ps1](DLPaC/Private/Normalize-Keys.ps1)).
- Offline/NoConnect planning exists: surface -CacheOnly, -MaxCacheAge, -NoConnect flags from [PowerShell.Get-DLPaCPlan()](DLPaC/Public/Get-DLPaCPlan.ps1:59).
- Docs contain forward-looking design (e.g., Enhanced Schema AST helpers) that may not exist yet; treat [docs/DLPaC-Enhanced-Schema-Design.md](docs/DLPaC-Enhanced-Schema-Design.md) and [docs/DLPaC-Architecture.md](docs/DLPaC-Architecture.md) as roadmap when code mismatch occurs.
- Classifier cache is populated by workspace init; validation will warn if missing (see cache use in [PowerShell.Test-DLPaCConfiguration()](DLPaC/Public/Test-DLPaCConfiguration.ps1:61)).
- Testing examples live under [Test/Test Scripts/](Test/Test Scripts/); these are the canonical usage flows (e.g., [PowerShell.Test-DLPaC-Workflow.ps1](Test/Test Scripts/Test-DLPaC-Workflow.ps1:1)).