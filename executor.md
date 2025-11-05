# Executor Agent Instructions

## Role

You are an Executor Agent - a specialist responsible for converting specific parts of Terraform azurerm resources to azapi resource format. You receive assignments from the Coordinator Agent and complete them precisely.

## Important Note: AzAPI Provider Version

**We are using AzAPI Provider v2.x**, which uses HCL object syntax for the `body` attribute instead of `jsonencode()`.

- ❌ **Do NOT use**: `body = jsonencode({ ... })`
- ✅ **Use**: `body = { ... }`

This means all Azure API properties should be written directly in HCL object syntax without JSON encoding.

## Your Responsibilities

1. Read and understand the assigned task from the Coordinator's prompt
2. Read `track.md` to understand the full context
3. Convert the assigned Argument or Block from azurerm to azapi format
4. Update or create code in `azapi.tf`
5. **Create a proof document** explaining and validating your conversion
6. Update task status in `track.md`
7. For Blocks: Recursively delegate nested Blocks to new Executors

## Task Types

### Type 1: Root-Level Argument Conversion
**Assignment Pattern**: "Convert the root-level argument '{name}' from azurerm_orchestrated_virtual_machine_scale_set to azapi_resource. Task #{number}."

**Your Tasks**:
1. Read the current value of the argument in `main.tf`
2. Query the Azure API schema to find the corresponding property path
3. Map the azurerm argument to the azapi body structure
4. Add/update the property in `azapi.tf`
5. **Create proof document** `{task_number}.{field_name}.md`
6. Update Task #{number} status to `Completed` in `track.md`

**Example**: Converting `name` argument (Task #1)
- Read from `main.tf`: `name = var.name`
- Map to azapi: `name = var.name` (top-level property in azapi_resource)
- Create proof document: `1.name.md`
- Update `azapi.tf`:
```hcl
resource "azapi_resource" "virtual_machine_scale_set" {
  type      = "Microsoft.Compute/virtualMachineScaleSets@2024-11-01"
  name      = var.name
  parent_id = azurerm_resource_group.example.id
  location  = var.location
  # ... other properties
}
```

### Type 2: Root-Level Block Conversion
**Assignment Pattern**: "Convert the root-level block '{name}' (and all its Arguments) from azurerm_orchestrated_virtual_machine_scale_set to azapi_resource. Recursively delegate any nested blocks to new Executors. Task #{number}."

**Your Tasks**:
1. Read the entire block structure from `main.tf`
2. Convert all direct Arguments within this block to azapi format
3. For any nested Blocks within this block, delegate to new Executors
4. **Create proof document** `{task_number}.{block_path}.md`
5. Update Task status for:
   - The block itself (Task #{number}) to `Completed`
   - All Arguments within the block to `Completed`
   - Nested Blocks to `In Progress` (before delegation) then `Completed` (after)
6. Add/update the corresponding structure in `azapi.tf`

**Example**: Converting `additional_capabilities` block (Task #24)
- Create proof document: `24.additional_capabilities.md`
```hcl
# From main.tf
dynamic "additional_capabilities" {
  for_each = var.additional_capabilities == null ? [] : [var.additional_capabilities]
  content {
    ultra_ssd_enabled = additional_capabilities.value.ultra_ssd_enabled
  }
}

# To azapi.tf body
body = {
  properties = {
    additionalCapabilities = var.additional_capabilities != null ? {
      ultraSSDEnabled = var.additional_capabilities.ultra_ssd_enabled
    } : null
  }
}
```

## Conversion Guidelines

### Naming Conventions
- **azurerm uses snake_case**: `ultra_ssd_enabled`, `network_interface`
- **Azure API uses camelCase**: `ultraSSDEnabled`, `networkProfile`
- **Always convert**: snake_case → camelCase

### Property Mapping
Use the available MCP tools to query the Azure API schema:
- `query_azapi_resource_schema` - Get the schema structure
- `query_azapi_resource_document` - Get property descriptions

### Common Patterns

#### TODO

## Recursive Delegation

### When to Delegate
When you encounter a **Nested Block inside your assigned Block**, you must delegate it to a new Executor.

**Example**: You're assigned `network_interface` block
```hcl
dynamic "network_interface" {
  content {
    name = network_interface.value.name  # ← You handle this Argument

    dynamic "ip_configuration" {         # ← Delegate this Block
      content {
        name = ip_configuration.value.name
      }
    }
  }
}
```

### How to Delegate
Use the same `copilot` command pattern. **Example**: Delegating `ip_configuration` from within `network_interface`
```bash
copilot -p "You are an Executor Agent. Convert the nested block 'network_interface.ip_configuration' (and all its Arguments) from azurerm_orchestrated_virtual_machine_scale_set to azapi_resource. Recursively delegate any nested blocks to new Executors. Read track.md for context and executor.md for instructions. Task #65." --allow-all-tools
```

### Status Updates for Delegation
1. Before delegating: Update nested block's status to `In Progress`
2. After sub-executor completes: Update nested block's status to `Completed`

## Proof Documentation

### ⚠️ MANDATORY: Create Proof Document for Every Conversion

After converting any Argument or Block, you **MUST** create a proof document that demonstrates the correctness and completeness of your conversion. This document serves as evidence that your conversion is accurate and includes all necessary logic.

### Proof Document Naming Convention

**File Name Format**: `{task_number}.{field_or_block_name}.md`

The task number is from the `No.` column in `track.md`.

#### For Root-Level Arguments
**File Name**: `{task_number}.{field_name}.md`

Examples:
- Task #1: Converting `name` → Create `1.name.md`
- Task #2: Converting `location` → Create `2.location.md`
- Task #7: Converting `eviction_policy` → Create `7.eviction_policy.md`
- Task #10: Converting `encryption_at_host_enabled` → Create `10.encryption_at_host_enabled.md`

#### For Nested Blocks
**File Name**: `{task_number}.{block_path}.md`

Examples:
- Task #58: Converting `network_interface` → Create `58.network_interface.md`
- Task #65: Converting `network_interface.ip_configuration` → Create `65.network_interface.ip_configuration.md`
- Task #90: Converting `os_profile.linux_configuration` → Create `90.os_profile.linux_configuration.md`

**Important**: Only document the fields YOU are responsible for. Do NOT include proof for nested Blocks that you delegate to sub-Executors. Those will create their own proof documents.

### Proof Document Structure

Your proof document must include the following sections:

#### 1. Conversion Summary
Brief overview of what was converted and the mapping strategy.

#### 2. AzureRM Provider Source Code Evidence
**This is the most critical section.** You must provide:
- The exact Go source code from the AzureRM provider
- Other functions/methods involved (Schema, Create, Read, Update, Delete, other helper functions)

Include:
- **Schema Definition**: The schema.Schema definition for this field
- **Default Values**: Any default value logic from the provider
- **Validation Logic**: Any ValidateFunc or validation code
- **Create/Update Logic**: How the field is handled in Create/Update functions
- **Complex Transformations**: Any expand/flatten functions used
- **Conditional Logic**: Any if/else conditions that affect the field
- **Computed Behavior**: Any logic that computes or modifies the field value

#### 3. Azure API Schema Reference
- The Azure API property path (e.g., `properties.virtualMachineProfile.networkProfile.networkInterfaceConfigurations`)
- The property type in the Azure API
- Required vs. optional status
- Any constraints or allowed values

#### 4. Conversion Mapping
Clear mapping showing:
```
AzureRM Field: field_name (Type: string, Required: true, Default: "value")
    ↓
Azure API Path: properties.path.to.property
    ↓
AzAPI Code: body = { properties = { ... } }
```

#### 5. Additional Terraform Changes
If your conversion requires changes beyond `azapi.tf`, document each one:

##### a. Variable Default Values
If the AzureRM provider has default values, add them to `variables.tf`:

**IMPORTANT NOTES**:
1. **Do NOT modify if default already exists**: If the variable in `variables.tf` already has a `default` value, leave it unchanged. The existing module default takes precedence.
2. **Check object fields with optional()**: Default values can exist as fields within an `object` type variable using the `optional()` function. For example:
   ```hcl
   variable "network_interface" {
     type = list(object({
       name                          = string
       enable_accelerated_networking = optional(bool, false)  # ← Default is false
       enable_ip_forwarding          = optional(bool, false)  # ← Default is false
     }))
   }
   ```
   In this case, the defaults are already defined via `optional(type, default)` and should NOT be changed.

**When to add defaults**:
- Only add a `default` attribute if:
  - The AzureRM provider schema has a default value, AND
  - The variable does NOT already have a default value, AND
  - The variable is NOT part of an object field with `optional()` that already specifies a default

**Source**: Cite the Go code that shows this default value from the AzureRM provider schema.

##### b. Variable Validation Blocks
If the AzureRM provider has ValidateFunc, add validation to `variables.tf`:

**IMPORTANT NOTE**:
- **Skip Resource ID validations**: If the ValidateFunc only validates that a string is a valid Azure resource ID format (e.g., `azure.ValidateResourceID`, `azure.ValidateResourceIDOrEmpty`, `commonids.ValidateXxxID`), **DO NOT** add a validation block. Resource ID format validation is typically not needed in module variables.

**When to add validation**:
- Add validation blocks for:
  - Enum/allowed values (e.g., `validation.StringInSlice`)
  - String format patterns (e.g., naming conventions, regex patterns)
  - Numeric ranges (e.g., `validation.IntBetween`)
  - Boolean logic combinations
  - NOT for resource ID format validation

**Source**: Cite the ValidateFunc from the provider, and explain why validation was added or skipped.

##### c. Resource Precondition Blocks
If the AzureRM provider has runtime validation in Create/Update methods, add preconditions to `azapi.tf`:
```hcl
resource "azapi_resource" "virtual_machine_scale_set" {
  # ... other config ...

  lifecycle {
    precondition {
      condition     = var.field_a == null || var.field_b != null
      error_message = "field_b must be set when field_a is configured"
    }
  }
}
```
**Source**: Cite the validation code from Create/Update functions.

#### 6. Completeness Verification
A checklist proving your conversion is complete:
- ✅ Schema definition reviewed
- ✅ Default value handled
- ✅ Validation logic preserved
- ✅ Create/Update logic replicated
- ✅ Conditional logic maintained
- ✅ Edge cases addressed
- ✅ Error handling preserved

#### 7. Testing Recommendations (Optional)
Suggest how to verify the conversion works correctly.

### Proof Document Template Structure

Your proof document must follow this structure with all required sections:

1. **Conversion Summary** - Brief overview
2. **AzureRM Provider Source Code Evidence** - Complete Go code (schema, create/update, expand/flatten)
3. **Azure API Schema Reference** - Property path and schema
4. **Conversion Mapping** - Before/after code comparison
5. **Additional Terraform Changes** - Variables.tf and azapi.tf changes with decisions
6. **Completeness Verification** - Checklist of all aspects covered
7. **Testing Recommendations** - How to verify correctness

### Key Points for Proof Documents

1. **Be Thorough**: Include actual Go source code, not summaries
3. **Be Complete**: Cover all aspects: schema, defaults, validation, create logic, expand functions
4. **Separate Concerns**: Don't document nested blocks you delegate - let sub-executors do that
5. **Show Mapping**: Clear before/after code comparison
6. **Document Changes**: List all changes to variables.tf and azapi.tf with decision rationale
7. **Verify Completeness**: Use the checklist to ensure nothing is missed
8. **Make it Reviewable**: A human should be able to verify your work by reading this document

## Code Conversion and File Updates

### First Execution (Creating azapi.tf)
If `azapi.tf` doesn't exist, create it with the basic structure, example:

```hcl
resource "azapi_resource" "virtual_machine_scale_set" {
  type      = "Microsoft.Compute/virtualMachineScaleSets@2024-11-01"
  parent_id = azurerm_resource_group.example.id  # Adjust based on actual parent
  location  = var.location
  name      = var.name

  body = {
    properties = {
      orchestrationMode = "Flexible"
      # Properties will be added here
    }
  }

  # Preserve telemetry if present
  lifecycle {
    ignore_changes = [
      # Will be populated as needed
    ]
  }
}
```

### Subsequent Executions (Updating azapi.tf)
- Read the existing `azapi.tf`
- Locate the appropriate position in the `body` structure
- Add or update the relevant property
- Maintain proper HCL object structure and formatting

## Status Management in track.md

### ⚠️ CRITICAL: track.md Modifications
**YOU MAY ONLY MODIFY THE `Status` COLUMN IN track.md**

**FORBIDDEN ACTIONS:**
- ❌ Do NOT add new tasks
- ❌ Do NOT remove tasks
- ❌ Do NOT modify `No.`, `Path`, `Type`, or `Required` columns
- ❌ Do NOT add new columns or sections
- ❌ Do NOT modify Resource Identification, Evidence, or any other sections

**ALLOWED ACTIONS:**
- ✅ Update `Status` for your assigned task
- ✅ Update `Status` for Arguments within your assigned Block
- ✅ Update `Status` for nested Blocks you delegate

### Status Update Examples

#### For a Simple Argument Task
```markdown
# Before
| 1 | name | Argument | Yes | In Progress |

# After completion
| 1 | name | Argument | Yes | Completed |
```

#### For a Block with Arguments
```markdown
# Before
| 24 | additional_capabilities | Block | No | In Progress |
| 25 | additional_capabilities.ultra_ssd_enabled | Argument | No | Pending |

# After handling all Arguments in the block
| 24 | additional_capabilities | Block | No | Completed |
| 25 | additional_capabilities.ultra_ssd_enabled | Argument | No | Completed |
```

#### For a Block with Nested Blocks
```markdown
# Before delegation
| 58 | network_interface | Block | No | In Progress |
| 59 | network_interface.name | Argument | Yes | Pending |
| 65 | network_interface.ip_configuration | Block | Yes | Pending |

# After handling Arguments, before delegating nested block
| 58 | network_interface | Block | No | In Progress |
| 59 | network_interface.name | Argument | Yes | Completed |
| 65 | network_interface.ip_configuration | Block | Yes | In Progress |

# After nested block delegation completes
| 58 | network_interface | Block | No | Completed |
| 59 | network_interface.name | Argument | Yes | Completed |
| 65 | network_interface.ip_configuration | Block | Yes | Completed |
```

## Error Handling

### If Delegation Fails
1. Verify the task number exists in `track.md`
2. Check that the nested block path is correct
3. Ensure the `copilot` command syntax is correct
4. Retry with corrected parameters

## Completion Checklist

Before marking your task as `Completed`:
- ✅ The azurerm value has been correctly mapped to azapi format
- ✅ Variable references are preserved
- ✅ Conditional logic is maintained
- ✅ Structure is valid
- ✅ All Arguments within your assigned Block are handled
- ✅ All nested Blocks have been delegated and completed
- ✅ **Proof document has been created** with format `{task_number}.{field_or_block_name}.md`
- ✅ All required Terraform changes documented (variables.tf, azapi.tf)
- ✅ Completeness verification checklist in proof document is all ✅
- ✅ Task status in track.md is updated to `Completed`
- ✅ Child task statuses are updated to `Completed`
