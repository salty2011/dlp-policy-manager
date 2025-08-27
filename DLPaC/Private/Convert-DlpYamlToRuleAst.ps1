<#
.SYNOPSIS
Phase 1 helper to build a DLPRuleAST from an existing DLPaCRule or raw condition objects.

.DESCRIPTION
Creates a basic AST with a single root logical group (AllOf) and one DLPConditionNode
per condition. No logical operator inference, normalization, or advanced validation
is performed in Phase 1. This is an internal stepping stone toward the richer
pipeline described in the enhanced schema spec in [DLPaC-Enhanced-Schema-Design.md](DLPaC-Enhanced-Schema-Design.md:1).

.PARAMETER Rule
A DLPaCRule instance whose Conditions collection will be transformed.

.PARAMETER Conditions
An array of condition objects (e.g., DLPaCCondition instances) used when a rule
object is not yet constructed (future YAML direct path).

.OUTPUTS
DLPRuleAST

.NOTES
Future phases will add:
 - Support for nested logical operators (allOf/anyOf/exceptAnyOf)
 - Normalization (merge, collapse, ordering)
 - Semantic validation
#>
function Convert-DlpYamlToRuleAst {
    [CmdletBinding(DefaultParameterSetName = 'FromRule')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'FromRule')]
        [DLPaCRule] $Rule,

        [Parameter(Mandatory = $true, ParameterSetName = 'FromConditions')]
        [object[]] $Conditions
    )

    process {
        $ast = [DLPRuleAST]::new()

        $sourceConditions = if ($PSCmdlet.ParameterSetName -eq 'FromRule') {
            $Rule.Conditions
        } else {
            $Conditions
        }

        if (-not $sourceConditions -or $sourceConditions.Count -eq 0) {
            Write-Verbose "Convert-DlpYamlToRuleAst: no conditions supplied; AST will be empty."
            return $ast
        }

        foreach ($c in $sourceConditions) {
            if ($null -eq $c) { continue }
            try {
                $node = [DLPConditionNode]::new($c)
                $ast.RootCondition.AddChild($node)
            }
            catch {
                Write-Warning "Convert-DlpYamlToRuleAst: failed to wrap condition of type '$($c.GetType().FullName)': $_"
            }
        }

        return $ast
    }
}