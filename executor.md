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

### Speical Patterns

This section describes how to handle special scanerios from the AzureRM provider when converting to AzAPI. Standard fields (without special attributes) are converted directly into the `body` block.

| Scanerio | Pattern | Required actions |
| --- | --- | --- |
| `Optional: true` **and** `Computed: true` (no `ForceNew`) | Special Case 1 | Assign directly in `body`, add ignore drift entry, update shared O+C trigger and updater. |
| `ForceNew: true` | Special Case 2 | Include in `body`, hook into shared ForceNew trigger, add `ignore_changes` only when also Computed. |
| Appears in `CustomizeDiff` logic | Special Case 3 | Mirror the diff hook (e.g. `ForceNewIfChange`) using triggers or preconditions; document behavior and guard conditions. |
| Prohibits specific value transitions in Create/Update | Special Case 4 | Recreate the guard via stable replacement triggers; reuse Special Case 3 data-source guidance when historic values are needed. |
| `Sensitive: true` **or** `WriteOnly` in Azure API | Special Case 5 | Place in `sensitive_body`, create/extract ephemeral variables, add version control variable. |

If the shared `terraform_data` or `azapi_update_resource` blocks mentioned below are missing, create them before wiring in new fields.

#### Special Case 1: Optional + Computed (Non-ForceNew)

- Purpose: Azure applies defaults, so Terraform must skip updates unless user supplied a value.
- Required steps:
  - Assign the property directly inside the main `body`.
  - Append `body.properties.fieldName` to the main resource `ignore_changes` list.
  - Extend the shared `terraform_data.properties_update_trigger` map with `"field_name" = tostring(var.field_name)`.
  - Extend the shared `azapi_update_resource.updater` body with the same assignment.

#### Special Case 2: ForceNew Fields

- Purpose: Any change forces replacement; we centralize replace triggers.
- Required steps:
  - Place the property in the main `body` (conditionally when Optional, directly when Required).
  - When Computed, add the property path to `ignore_changes` to suppress drift.
  - Add `"field_name" = tostring(var.field_name)` to the shared `terraform_data.force_new_trigger`.
  - Reference `terraform_data.force_new_trigger` inside the resource `lifecycle.replace_triggered_by` list.

```hcl
replace_triggered_by = [terraform_data.force_new_trigger]
```

#### Special Case 3: CustomizeDiff Hooks

- Purpose: The provider sometimes wires custom diff logic (for example `pluginsdk.ForceNewIfChange`) so replacements or validations only occur under specific conditions.
- Required steps:
  - Search the resource for `CustomizeDiff` whenever your field is mentioned; include the relevant Go snippet in your proof document.
  - Reproduce the intent in AzAPI: wire replacement triggers via `terraform_data.force_new_trigger` or add lifecycle `precondition` blocks so behaviour matches the callback (only trigger when the same condition would fire).
  - When the hook suppresses replacement for certain values (e.g. `old != 0 && new == 0`), ensure your trigger logic respects that guard rather than always forcing replacement.
  - Call out in the proof doc how null/zero values, user-supplied values, and updates interact with the recreated logic.
  - If the provider logic needs the previous value (for example, reading `old` inside the callback), add a `data "azapi_resource"` reader so the module can load the existing resource state. Ensure the data block uses the same `type` string as the resource, sets `ignore_not_found = true`, and `response_export_values = ["*"]`. Always check the `exists` attribute before dereferencing historic values; if `exists` is `false`, treat the old value as absent. See https://registry.terraform.io/providers/Azure/azapi/latest/docs/data-sources/resource for full syntax.

Example provider snippet:

```go
CustomizeDiff: pluginsdk.CustomDiffInSequence(
    // The behaviour of the API requires this, but this could be removed when https://github.com/Azure/azure-rest-api-specs/issues/27373 has been addressed
    pluginsdk.ForceNewIfChange("default_node_pool.0.upgrade_settings.0.drain_timeout_in_minutes", func(ctx context.Context, old, new, meta interface{}) bool {
        return old != 0 && new == 0
    }),
),
```

#### Special Case 4: Prohibited Value Transitions

- Purpose: Some Create/Update methods explicitly block changing a field from one specific value to another (for example preventing `single_placement_group` from flipping `false → true`).
- Required steps:
  - Treat these like Special Case 3: capture the Go logic in your proof document and note the forbidden transition.
  - Design a deterministic expression (for example a local that hashes the forbidden diff) that changes only when the prohibited transition occurs. Surface this expression through `replace_triggers_external_values` on the `azapi_resource` so the replacement fires when the illegal transition appears, yet settles back to `null` once the remediation apply completes.
    * Do **not** use the raw list of removed items directly as a trigger value. After the first forced replacement Terraform will see the list as empty on the next plan, which would make the trigger keep changing and cause an infinite replace loop. Instead, derive a stable hash (or other deterministic scalar) whose value stops changing once the remediation apply completes.
  - Reuse the `data "azapi_resource"` reader pattern from Special Case 3 when you must compare against the deployed value. Remember to guard on `exists` before reading historic values.
  - Ensure the trigger value is stable (no random suffixes). The provided `zones_replacement_trigger` example shows how to build such a hash from removed items.

Example provider snippet:

```go
CustomizeDiff: pluginsdk.CustomDiffWithAll(
			// Removing existing zones is currently not supported for Virtual Machine Scale Sets
			pluginsdk.ForceNewIfChange("zones", func(ctx context.Context, old, new, meta interface{}) bool {
				oldZones := zones.ExpandUntyped(old.(*schema.Set).List())
				newZones := zones.ExpandUntyped(new.(*schema.Set).List())

				for _, ov := range oldZones {
					found := false
					for _, nv := range newZones {
						if ov == nv {
							found = true
							break
						}
					}

					if !found {
						return true
					}
				}

				return false
			}),
```

```go
if d.HasChange("single_placement_group") {
    // Since null is now a valid value for single_placement_group
    // make sure it is in the config file before you set the value
    // on the update props...
    if !pluginsdk.IsExplicitlyNullInConfig(d, "single_placement_group") {
        singlePlacementGroup := d.Get("single_placement_group").(bool)
        if singlePlacementGroup {
            return fmt.Errorf("`single_placement_group` cannot be changed from `false` to `true`")
        }
        updateProps.SinglePlacementGroup = pointer.To(singlePlacementGroup)
    }
}
```

Example Terraform trigger design:

```hcl
# Zones drift detection
# Detects when zones are removed from configuration, which requires resource recreation
# This mimics the azurerm provider behavior that prevents zone removal
locals {
  # Get desired zones from configuration (empty list if not specified)
  desired_zones = var.zones != null ? tolist(var.zones) : []
  # Get existing zones from the deployed resource (empty list if resource doesn't exist)
  existing_zones = data.azapi_resource.existing_vmss.exists ? try(
    data.azapi_resource.existing_vmss.output.zones,
    []
  ) : []
  # Replacement trigger: changes when zones are removed to force resource recreation
  # Use a hash so the trigger is stable after the remediation apply completes
  removed_zones_list = [
    for zone in local.existing_zones : zone
    if !contains(local.desired_zones, zone)
  ]
  # Check if any existing zone has been removed
  zones_removed = length(local.existing_zones) > 0 && length([
    for zone in local.existing_zones : zone
    if !contains(local.desired_zones, zone)
  ]) > 0
  zones_replacement_trigger = local.zones_removed ? sha256(jsonencode(sort(local.removed_zones_list))) : null
}

# Surface the stable triggers in the resource so only the prohibited transitions force recreation
resource "azapi_resource" "virtual_machine_scale_set" {
  # ...
  replace_triggers_external_values = {
    zones_removal_trigger          = local.zones_replacement_trigger
    single_placement_group_trigger = local.single_placement_group_trigger # Define similarly using a stable hash of the forbidden diff
  }
}
```

---

#### Special Case 5: Sensitive and WriteOnly Fields

- **Purpose**: Azure API write-only properties (such as passwords, secrets, keys) must be placed in `sensitive_body` instead of `body`. Changes are tracked via version variables to ensure updates are sent only when values change.

- **Identification**: A field requires Special Case 5 when:
  - AzureRM provider schema has `Sensitive: true`, OR
  - Azure API documentation marks the property as `WriteOnly`, OR
  - The field name suggests sensitive data (e.g., `password`, `secret`, `key`, `token`)

- **Required steps**:

  1. **Place property in `sensitive_body`** (not `body`):
     ```hcl
     resource "azapi_resource" "virtual_machine_scale_set" {
       # ... other config ...

       body = {
         properties = {
           # Regular properties here
         }
       }

       sensitive_body = {
         properties = {
           virtualMachineProfile = {
             osProfile = {
               adminPassword = var.admin_password  # ← Sensitive field
             }
           }
         }
       }

       sensitive_body_version = {
         "properties.virtualMachineProfile.osProfile.adminPassword" = var.admin_password_version
       }
     }
     ```

  2. **Create or extract ephemeral variable**:

     **If the variable already exists** (e.g., `var.admin_password`):
     - Update the existing variable definition in `variables.tf`:
       ```hcl
       variable "admin_password" {
         type        = string
         description = "(Optional) The admin password"
         ephemeral   = true  # ← Add this
         # Remove: sensitive = true  ← Remove if present
       }
       ```

     **If the field is part of an object variable** (e.g., `var.os_profile.windows_configuration.admin_password`):
     - Extract it into a new standalone variable in `variables.tf`:
       ```hcl
       variable "admin_password" {
         type        = string
         default     = null
         description = "(Optional) The admin password for the VM. Extracted from os_profile for ephemeral handling."
         ephemeral   = true
       }
       ```
     - Update `main.tf` to use the new variable
     - Document the extraction in the proof document

  3. **Create version control variable**:

     For each sensitive variable `var.xxx`, create a corresponding `var.xxx_version` in `variables.tf`:
     ```hcl
     variable "admin_password_version" {
       type        = string
       default     = null
       description = "Version tracker for admin_password. Increment to force update of the password."

       validation {
         condition     = var.admin_password != null ? var.admin_password_version != null : true
         error_message = "admin_password_version must be set when admin_password is provided."
       }
     }
     ```

     **Version variable requirements**:
     - Default value: `null` (not `"1"`)
     - Validation: If the original variable is not `null`, the version must also not be `null`
     - Type: `string`
     - Not ephemeral, not sensitive

     **Version variable naming**: Always use `{original_var_name}_version` pattern:
     - `var.admin_password` → `var.admin_password_version`
     - `var.user_data_base64` → `var.user_data_base64_version`
     - `var.custom_secret` → `var.custom_secret_version`

  4. **Path format in `sensitive_body_version`**:

     The path follows the structure in `sensitive_body` using dot notation:
     - Simple property: `"properties.fieldName"`
     - Nested property: `"properties.parent.child.fieldName"`
     - Array item: `"properties.items[0].fieldName"`

     **Examples**:
     ```hcl
     sensitive_body_version = {
       # Simple nested path
       "properties.virtualMachineProfile.osProfile.adminPassword" = var.admin_password_version

       # Multiple sensitive fields
       "properties.virtualMachineProfile.osProfile.adminPassword" = var.admin_password_version
       "properties.virtualMachineProfile.userData"                = var.user_data_base64_version

       # Array item (if applicable)
       "properties.secrets[0].certificateUrl" = var.certificate_url_version
     }
     ```

- **Key behaviors**:
  - `sensitive_body` is **merged** into `body` when constructing the Azure API request
  - Properties in `sensitive_body_version` are **included in the request only when the version changes**
  - If version remains the same, the property is **omitted** (Azure retains the existing value)
  - Increment the version variable to force an update of the sensitive field

- **Variable requirements summary**:
  - Original variable: `ephemeral = true`, remove `sensitive = true` if present
  - Version variable: Type `string`, default `null`, validation block required, not ephemeral, not sensitive
  - Extracted variables: Follow the same pattern as above

- **Complex expression handling**:

  **⚠️ CRITICAL**: Special Case 5 only applies when the sensitive field is assigned a **simple variable reference**.

  **Acceptable patterns** (can be converted):
  - Direct variable: `admin_password = var.admin_password`
  - Object field: `admin_password = var.os_profile.windows_configuration.admin_password`
  - Lookup from variable: `protected_settings = lookup(var.extension_protected_setting, extension.value.name, "")`

  **Unacceptable patterns** (cannot be converted):
  - Conditional expressions: `admin_password = var.use_default ? "default123" : var.admin_password`
  - Function calls: `admin_password = base64encode(var.admin_password)`
  - String interpolation: `admin_password = "${var.prefix}-${var.admin_password}"`
  - Complex logic: `admin_password = length(var.passwords) > 0 ? var.passwords[0] : null`

  **When encountering complex expressions**:
  1. **DO NOT attempt conversion** - Complex expressions cannot be reliably tracked with version variables
  2. **Update `track.md` status to `Error`** - Mark the field status as `Error` instead of `Completed`
  3. **Create proof document explaining the issue**:
     - Document the complex expression found in `main.tf`
     - Explain why it cannot be converted (version tracking requires simple variable references)
     - Suggest manual intervention or refactoring approaches
  4. **Add error note in track.md** - In the `Proof Doc` column, add: `[X.field.md](X.field.md) - Error: Complex expression`

  **Example track.md update for failed conversion**:
  ```markdown
  | 67 | os_profile.linux_configuration.admin_password | Argument | No | Error | [67.admin_password.md](67.admin_password.md) - Complex expression |
  ```

  **Example proof document for failed conversion**:
  ```markdown
  # Task #67: Conversion of `admin_password` - ERROR

  ## Conversion Status: ❌ FAILED

  **Reason**: The field uses a complex expression that cannot be converted to Special Case 5.

  ## Source Code (main.tf)

  ```hcl
  admin_password = var.use_generated ? random_password.admin.result : var.admin_password
  ```

  ## Problem

  Special Case 5 requires simple variable references for version tracking. This field uses a conditional expression with a dynamically generated value (`random_password.admin.result`), which cannot be tracked via `sensitive_body_version`.

  ## Recommendation

  Manual intervention required. Consider one of:
  1. Refactor to use only `var.admin_password` and handle generation outside Terraform
  2. Split into two separate resources based on `var.use_generated`
  3. Keep this field in the azurerm provider resource if migration is not critical
  ```

---

#### Proof Documentation Requirements for Special Cases

When converting fields with special attributes, your proof document must include:

1. **Pattern Identification**
   - Quote the exact AzureRM schema showing `Optional`, `Computed`, `ForceNew`, `Sensitive`
   - Identify which special case applies (1-5) or state "standard conversion"
   - Explain the decision rationale

2. **Component Updates**
   - List which shared components this field uses
   - Show the exact lines added to each component
   - Confirm all three locations are updated (for O+C fields)
   - For Special Case 5: List variable changes (ephemeral, version variable creation/extraction)

3. **Behavior Verification**
   - What happens when value is `null`
   - What happens when value changes
   - What happens with Azure's server-side defaults (if applicable)
   - For Special Case 5: What happens when version is incremented vs unchanged

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

After completing the conversion work for any Argument or Block, pause and re-read your changes with a critical eye before you start documenting. Once you are satisfied that the mapping is correct and complete, you **MUST** create a proof document that demonstrates the correctness and completeness of your conversion. This document serves as evidence that your conversion is accurate and includes all necessary logic.

### 📝 CRITICAL: Keep Proof Documents Concise and Focused

**Writing Style Requirements:**
- ✅ **Be concise and precise** - Get to the point quickly
- ✅ **Show, don't tell** - Code examples over lengthy explanations
- ✅ **Focus on what matters** - Only include essential evidence
- ❌ **Avoid verbosity** - Don't repeat information unnecessarily
- ❌ **Don't over-explain** - Trust the reader's technical knowledge

**Document Opening:**
1. **Start with the converted code** - Show the final AzAPI result FIRST
2. **Then provide context** - Follow with explanation and evidence
3. **Keep it scannable** - Use clear headings and code blocks

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

Your proof document must include the following sections **in this order**:

#### 1. Converted AzAPI Code
**⚠️ START HERE** - Show the converted code FIRST before any explanation.

Display the final result in `azapi.tf` for the field(s) you converted:
```hcl
resource "azapi_resource" "virtual_machine_scale_set" {
  # ... existing config ...

  # Your conversion here
  body = {
    properties = {
      yourField = var.your_field  # ← Show the actual mapping
    }
  }
}
```

**Keep it focused**: Only show the relevant part you converted, not the entire resource.

#### 2. Conversion Summary
**One or two sentences maximum** - What field(s) did you convert and what pattern was used (standard, Special Case 1-4, etc.).

#### 3. AzureRM Provider Source Code Evidence
**Be selective** - Only include the code that matters for this specific field.

Essential evidence to include:
- **Schema Definition** (always required): The `schema.Schema` entry showing `Type`, `Required`, `Optional`, `Computed`, `ForceNew`, `Default`
- **Create/Update Logic** (if field has special handling): Relevant snippets showing how the field is processed
- **Validation/Defaults** (if applicable): Only if they affect the conversion

**Omit:**
- ❌ Full function signatures and imports
- ❌ Unrelated fields from the same function
- ❌ Boilerplate error handling that doesn't affect conversion
- ❌ Comments that don't provide value

**Example - Good (concise):**
```go
"name": {
    Type:         pluginsdk.TypeString,
    Required:     true,
    ForceNew:     true,
    ValidateFunc: computeValidate.VirtualMachineName,
},
```

**Example - Bad (verbose):**
```go
// Full function with 50+ lines when only the schema matters
```

#### 4. Azure API Schema Reference
**One-liner format preferred:**
- Property path: `properties.path.to.field`
- Type: `String` | `Boolean` | `Integer` | `Object` | etc.
- Required: Yes/No

**Only expand if there are special constraints or enum values.**

#### 5. Mapping Summary
**Ultra-concise** - Show the transformation in one diagram:
```
azurerm: field_name (snake_case, Type: string, Required: true)
   ↓
azapi: properties.fieldName (camelCase, Type: String)
   ↓
Pattern: [Standard | Special Case 1-4]
```

**Note:** Since you already showed the code in section 1, this should be just a quick reference.

#### 6. Additional Terraform Changes
**Only include this section if you made changes to `variables.tf` or added preconditions.**

If your conversion requires changes beyond `azapi.tf`, document each one **concisely**:

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

#### 7. Completeness Verification
**Quick checklist** - No explanations needed, just checkmarks:
- ✅ Schema definition reviewed
- ✅ Default value handled (if any)
- ✅ Validation preserved (if any)
- ✅ Special patterns applied (if applicable)
- ✅ Variables.tf updated (if needed)

### Proof Document Template Structure

**MANDATORY ORDER** - Follow this exact structure:

1. **Converted AzAPI Code** - ⚠️ **START HERE** - Show final result first
2. **Conversion Summary** - 1-2 sentences maximum
3. **AzureRM Provider Source Code Evidence** - Only essential schema and logic
4. **Azure API Schema Reference** - One-liner preferred
5. **Mapping Summary** - Quick diagram
6. **Additional Terraform Changes** - Only if changes were made
7. **Completeness Verification** - Checkmarks only

**Length Target:**
- ✅ Simple fields: 1-2 pages
- ✅ Complex fields with Special Cases: 2-4 pages
- ❌ Never exceed 5 pages unless absolutely necessary

### Key Points for Proof Documents

1. **Lead with code**: Show the converted result FIRST, explanations SECOND
2. **Be concise**: Every sentence should add value, remove fluff
3. **Focus on essentials**: Only include Go code that affects the conversion
4. **One page is better**: Aim for brevity, expand only when necessary
5. **Separate concerns**: Don't document nested blocks you delegate
6. **Trust the reader**: Don't explain obvious mappings or standard Terraform concepts
7. **Scannable format**: Use clear sections, code blocks, and bullet points
8. **Verify completeness**: Use the checklist, but keep it simple

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
**YOU MAY ONLY MODIFY THE `Status` AND `Proof Doc` COLUMNS IN track.md**

**FORBIDDEN ACTIONS:**
- ❌ Do NOT add new tasks
- ❌ Do NOT remove tasks
- ❌ Do NOT modify `No.`, `Path`, `Type`, or `Required` columns
- ❌ Do NOT add new columns or sections (the `Proof Doc` column already exists)
- ❌ Do NOT modify Resource Identification, Evidence, or any other sections

**ALLOWED ACTIONS:**
- ✅ Update `Status` for your assigned task
- ✅ Update `Proof Doc` with a markdown link to your proof document
- ✅ Update `Status` for Arguments within your assigned Block
- ✅ Update `Proof Doc` for Arguments within your assigned Block
- ✅ Update `Status` for nested Blocks you delegate

### Status Update Examples

#### For a Simple Argument Task
```markdown
# Before
| 1 | name | Argument | Yes | In Progress | |

# After completion (with proof document link)
| 1 | name | Argument | Yes | Completed | [1.name.md](1.name.md) |
```

#### For a Failed Conversion (Complex Expression)
```markdown
# Before
| 67 | os_profile.linux_configuration.admin_password | Argument | No | In Progress | |

# After discovering complex expression (cannot convert)
| 67 | os_profile.linux_configuration.admin_password | Argument | No | Error | [67.admin_password.md](67.admin_password.md) - Complex expression |
```

**Proof Doc Link Format:**
- Use markdown link syntax: `[filename.md](filename.md)`
- The link text should be the filename
- The link target should be the relative path (just the filename in the root directory)
- Example: `[1.name.md](1.name.md)` or `[24.additional_capabilities.md](24.additional_capabilities.md)`

#### For a Block with Arguments
```markdown
# Before
| 24 | additional_capabilities | Block | No | In Progress | |
| 25 | additional_capabilities.ultra_ssd_enabled | Argument | No | Pending | |

# After handling all Arguments in the block (with proof document links)
| 24 | additional_capabilities | Block | No | Completed | [24.additional_capabilities.md](24.additional_capabilities.md) |
| 25 | additional_capabilities.ultra_ssd_enabled | Argument | No | Completed | [24.additional_capabilities.md](24.additional_capabilities.md) |
```

**Note:** For a Block and its direct Arguments, they typically share the same proof document, as the proof document for the Block includes the conversion of all its Arguments.

#### For a Block with Nested Blocks
```markdown
# Before delegation
| 58 | network_interface | Block | No | In Progress | |
| 59 | network_interface.name | Argument | Yes | Pending | |
| 65 | network_interface.ip_configuration | Block | Yes | Pending | |

# After handling Arguments, before delegating nested block
| 58 | network_interface | Block | No | In Progress | [58.network_interface.md](58.network_interface.md) |
| 59 | network_interface.name | Argument | Yes | Completed | [58.network_interface.md](58.network_interface.md) |
| 65 | network_interface.ip_configuration | Block | Yes | In Progress | |

# After nested block delegation completes (nested block has its own proof doc)
| 58 | network_interface | Block | No | Completed | [58.network_interface.md](58.network_interface.md) |
| 59 | network_interface.name | Argument | Yes | Completed | [58.network_interface.md](58.network_interface.md) |
| 65 | network_interface.ip_configuration | Block | Yes | Completed | [65.network_interface.ip_configuration.md](65.network_interface.ip_configuration.md) |
```

**Note:**
- Parent Block and its direct Arguments share the same proof document
- Nested Blocks have their own separate proof documents (created by sub-executors)
- Always add the proof document link when marking a task as `Completed`

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
- ✅ **Proof Doc link in track.md is added** with format `[filename.md](filename.md)`
- ✅ Child task statuses are updated to `Completed`
- ✅ Child task Proof Doc links are added (pointing to the parent's or their own proof document)
