# DLP Rules: YAML Schema Definition

## Version: 1.2.0

## About

This document defines the YAML schema for Data Loss Prevention (DLP) rules within Microsoft Purview Compliance. It outlines the structure and attributes for creating and managing DLP rules as code.

## Schema

```yaml
rules:
  - name: <string>
    description: <string>
    state: <string>
    conditions:
      ALL:
        operator: <string>
        sit:
          - name: <string>
            confidence: <string>
        trainable_classifier:
          - name: <string>
            confidence: <string>
        labels:
          - name: <string>
            id: <string>
        access_scope: <string>
      Exchange:
        operator: <string>
        content:
          operator: <string>
          groups:
            - name: <string>
              operator: <string>
              sit:
                - name: <string>
                  confidence: <string>
              trainable_classifier:
                - name: <string>
                  confidence: <string>
              labels:
                - name: <string>
                  id: <string>
        access_scope: <string>
      SharePoint:
        # Similar structure to Exchange
      OneDrive:
        # Similar structure to Exchange
    extensions:
      - <string>
```

## Attributes

| Attribute  | Type   | Required | Description                                 |
|------------|--------|----------|---------------------------------------------|
| name       | string | Yes      | Unique name of the rule                     |
| description| string | No       | Summary of the rule's purpose               |
| state      | string | Yes      | Operating state of the rule                 |
| conditions | object | Yes      | Conditions that trigger the rule            |
| extensions | array  | No       | File extensions the rule applies to         |

### Detailed Attribute Information

#### name
- Constraints: Must be unique across all rules
- Example: `"HighConfidenceRuleTest6"`

#### description
- Recommended: Yes
- Example: `"This rule detects high-confidence PII across all locations"`

#### state
- Accepted Values:
  - `enable`: Rule is active and enforced
  - `disable`: Rule is inactive
- Default Value: `enable`

#### conditions
- Type: Complex object
- Structure:
  - `ALL`: Conditions applied across all locations
    - `operator`: Operator for combining conditions
      - Accepted Values: `and`, `or`
    - `sit`: Array of Sensitive Information Types
    - `trainable_classifier`: Array of Trainable Classifiers
    - `labels`: Array of Sensitivity Labels
    - `access_scope`: Content sharing scope
      - Accepted Values: `InOrganization`, `NotInOrganization`
  - `Exchange`: Conditions specific to Exchange
    - `operator`: Operator for combining content groups
    - `content`: Content-specific conditions (similar to previous structure)
    - `access_scope`: Content sharing scope (same as ALL)
  - `SharePoint`: Conditions specific to SharePoint (similar to Exchange)
  - `OneDrive`: Conditions specific to OneDrive (similar to Exchange)

Note: Each location (ALL, Exchange, SharePoint, OneDrive) can have its own set of conditions. The ALL location is limited to SIT, Label, Trainable Classifiers, and access_scope.

#### extensions
- Type: Array of strings
- Description: File extensions the rule applies to
- Example: `["docx", "pdf", "xlsx"]`

## Example Rule

```yaml
rules:
  - name: HighConfidenceRuleTest6
    description: Detects high-confidence PII shared outside the organization
    state: enable
    conditions:
      ALL:
        operator: and
        sit:
          - name: "U.S. Social Security Number (SSN)"
            confidence: High
        trainable_classifier:
          - name: "PII Classifier"
            confidence: High
        access_scope: NotInOrganization
      Exchange:
        operator: and
        content:
          operator: and
          groups:
            - name: "Exchange - PII Group"
              operator: and
              sit:
                - name: "All Full Names"
                  confidence: Medium
              labels:
                - name: "Business"
                  id: '50979d44-1178-4a2d-a7e8-cd6729a732e5'
        access_scope: NotInOrganization
    extensions:
      - docx
      - pdf
      - xlsx
```

## Best Practices

1. Use descriptive rule names for easy identification.
2. Provide clear and concise descriptions for each rule.
3. Use the ALL location for conditions that should apply across all content locations.
4. Carefully structure location-specific conditions to accurately capture the intended data protection scenario.
5. Use condition groups within location-specific conditions to organize related conditions for better readability and management.
6. Regularly review and update rules to ensure they align with current compliance and security needs.
7. Be mindful of the confidence levels set for Sensitive Information Types and Trainable Classifiers.
8. Consider the impact of file extension restrictions on the rule's scope.
9. Use the `access_scope` condition to control rules based on content sharing, both globally and per-location as needed.

## Notes for AI Code Generation

- Validate all fields, including type checking and constraint enforcement.
- Ensure rule name uniqueness across all rules.
- Implement logic to handle the nested structure of conditions, including different operators at various levels and for different locations.
- Validate that specified Sensitive Information Types, Trainable Classifiers, and Sensitivity Labels exist in the system.
- Generate appropriate warnings or errors for complex or potentially conflicting condition combinations.
- Implement export functionality for existing rules to this YAML format.
- Ensure that conditions specified in the ALL location only include SIT, Label, Trainable Classifiers, and access_scope.
- Validate that the `access_scope` value is one of the accepted values: `InOrganization` or `NotInOrganization`.