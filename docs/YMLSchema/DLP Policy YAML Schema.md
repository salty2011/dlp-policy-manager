# DLP as Code: YAML Schema Definition

## Version: 1.2.0

## About

This document defines the YAML schema for Data Loss Prevention (DLP) policies. It outlines the structure and attributes for creating and managing DLP policies as code, similar to Terraform.

## Schema

```yaml
policies:
  - name: <string>
    description: <string>
    mode: <string>
    locations:
      - <string>
    split-by-type: <boolean>
    priority: <integer>
    rules:
      - <string>
```

## Attributes

| Attribute     | Type             | Required | Description                                       |
|---------------|------------------|----------|---------------------------------------------------|
| name          | string           | Yes      | Unique name of the policy                         |
| description   | string           | No       | Summary of the policy's purpose                   |
| mode          | string           | Yes      | Operating mode of the policy                      |
| locations     | array of strings | Yes      | List of locations where the policy applies        |
| split-by-type | boolean          | No       | Whether to create separate policies by type       |
| priority      | integer          | No       | Policy priority (lower number = higher priority)  |
| rules         | array of strings | No       | List of rule names associated with this policy    |

### Detailed Attribute Information

#### name
- Constraints: Must be unique within the organization
- Example: `"Confidential Data Policy"`

#### description
- Recommended: Yes
- Example: `"Prevents sharing of confidential data outside the organization"`

#### mode
- Accepted Values:
  - `enable`: Policy is active and enforcing rules
  - `disable`: Policy is inactive
  - `audit`: Policy is active but only logging violations (TestWithNotifications)
  - `silent`: Policy is active but not logging or notifying (TestWithoutNotifications)
- Default Value: `audit`

#### locations
- Accepted Values:
  - `Exchange`
  - `SharePoint`
  - `OneDrive`

#### split-by-type
- Default Value: `false`

#### priority
- Default Value: System-assigned based on creation order
- Constraints: Must be unique across all policies

#### rules
- Note: Each string should correspond to a rule name or identifier that is defined in either deployed ruleset or in the yaml rules defined.

## Example Policy

```yaml
policies:
  - name: Confidential Data Protection
    description: Prevents sharing of confidential data outside the organization
    mode: audit
    locations:
      - Exchange
      - SharePoint
    split-by-type: false
    priority: 1
    rules:
      - detect_ssn
      - detect_credit_card
```

## Best Practices

1. Use descriptive policy names for easy identification.
2. Provide clear and concise descriptions for each policy.
3. Start with 'audit' mode for new policies to test impact before enforcement.
4. Regularly review and update policies for current compliance and security needs.
5. Carefully manage policy priorities to ensure desired application order.
6. Use consistent naming conventions for rules across policies.

## Notes for AI Code Generation

- Validate all fields, including type checking and constraint enforcement.
- Ensure policy name uniqueness within an organization.
- Verify that specified locations are from the accepted list.
- Handle priority assignment and potential conflicts.
- Confirm existence of referenced rules when processing policy definitions.
- Implement export functionality for existing policies to this YAML format.