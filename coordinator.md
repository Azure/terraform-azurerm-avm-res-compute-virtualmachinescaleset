# Coordinator Agent Instructions

## Role

You are the Coordinator Agent - a project manager responsible for orchestrating the conversion of Terraform azurerm resources to azapi resources. You delegate tasks to Executor Agents and track their progress.

## Your Responsibilities

1. Read and understand the `track.md` file
2. Identify tasks that are ready to be executed
3. Delegate tasks to Executor Agents using the `copilot` CLI
4. Monitor progress until all tasks are completed

## Task Delegation Strategy

### Root-Level Arguments
- **Delegate individually**: Each root-level Argument should be assigned to a separate Executor Agent
- Example: `name`, `location`, `resource_group_name` are three separate tasks

### Nested Blocks
- **Delegate as a whole**: Each root-level Nested Block should be assigned to ONE Executor Agent
- The Executor will handle all Arguments within that block
- The Executor will recursively delegate any nested Nested Blocks to new Executors
- Example: The entire `network_interface` block (including its Arguments like `name`, `dns_servers`, etc.) goes to one Executor
- The Executor handling `network_interface` will delegate `ip_configuration` block to another Executor

## Workflow

### Step 1: Read track.md

### Step 2: Identify Next Task
- Find the first task with `Status: Pending`
- Check if it's a root-level Argument or a root-level Block
- If it's a nested block's argument, which means the previous migration has been stopped and the block has only been partial migrated, you should re-delegate the top-level nested block to an executor agent.
- Verify no dependencies are blocking this task

### Step 3: Delegate to Executor

#### For Root-Level Arguments:

Example:
```bash
copilot -p "You are an Executor Agent. Convert the root-level argument 'name' from azurerm_orchestrated_virtual_machine_scale_set to azapi_resource. Read track.md for context and executor.md for instructions. Task #1." --allow-all-tools
```

#### For Root-Level Nested Blocks:
```bash
copilot -p "You are an Executor Agent. Convert the root-level block '{path}' (and all its Arguments) from azurerm_orchestrated_virtual_machine_scale_set to azapi_resource. Recursively delegate any nested blocks to new Executors. Read track.md for context and executor.md for instructions. Task #{number}." --allow-all-tools
```

Example:
```bash
copilot -p "You are an Executor Agent. Convert the root-level block 'network_interface' (and all its Arguments) from azurerm_orchestrated_virtual_machine_scale_set to azapi_resource. Recursively delegate any nested blocks to new Executors. Read track.md for context and executor.md for instructions. Task #58." --allow-all-tools
```

### Step 4: Update Task Status

Before delegating:
```markdown
| 1 | name | Argument | Yes | In Progress |
```

After successful completion:
```markdown
| 1 | name | Argument | Yes | Completed |
```

If execution fails:
```markdown
| 1 | name | Argument | Yes | Failed |
```

### Step 4: Repeat
- Continue with the next Pending task
- Work through the list sequentially (by task number)
- Stop when all tasks show `Status: Completed`

## Status Management Rules

### Allowed Status Values
- `Pending` - Task not started
- `In Progress` - Task currently being executed
- `Completed` - Task successfully finished
- `Failed` - Task encountered an error

### Update Frequency
- Update to `In Progress` BEFORE calling `copilot`
- Update to `Completed` or `Failed` AFTER the Executor finishes

### Concurrency
- Process tasks sequentially (one at a time)
- Do NOT run multiple tasks in parallel
- Wait for Executor to complete before moving to next task

## Important Constraints

### ⚠️ CRITICAL: track.md Modifications
**YOU MAY ONLY MODIFY THE `Status` COLUMN IN track.md**

**FORBIDDEN ACTIONS:**
- ❌ Do NOT add new tasks to track.md
- ❌ Do NOT remove tasks from track.md
- ❌ Do NOT modify the `No.`, `Path`, `Type`, or `Required` columns
- ❌ Do NOT add new columns
- ❌ Do NOT modify any other sections of track.md (Resource Identification, Evidence, etc.)
- ❌ Do NOT create new markdown sections

**ALLOWED ACTIONS:**
- ✅ Change `Status` from `Pending` to `In Progress`
- ✅ Change `Status` from `In Progress` to `Completed`
- ✅ Change `Status` from `In Progress` to `Failed`

### File Creation
- The first Executor (handling root-level arguments) will create `azapi.tf`
- Subsequent Executors will append to `azapi.tf`
- After all conversions, an Executor will create the `moved` block

## Task Identification Rules

### Root-Level Items
Items are considered "root-level" if their `Path` contains NO dots (`.`)

Examples:
- ✅ Root-level Argument: `name`, `location`, `tags`
- ✅ Root-level Block: `identity`, `network_interface`, `os_disk`
- ❌ NOT root-level: `network_interface.name`, `os_disk.caching`

### Nested Items
Items with dots in their `Path` are nested and should NOT be directly delegated by the Coordinator

Examples:
- `network_interface.name` - Will be handled by the Executor working on `network_interface`
- `os_profile.linux_configuration` - Will be handled by the Executor working on `os_profile`

## Example Workflow

### Initial State (from track.md)
```markdown
| No. | Path | Type | Required | Status |
|-----|------|------|----------|--------|
| 1 | name | Argument | Yes | Pending |
| 2 | resource_group_name | Argument | Yes | Pending |
| 3 | location | Argument | Yes | Pending |
...
| 24 | additional_capabilities | Block | No | Pending |
| 25 | additional_capabilities.ultra_ssd_enabled | Argument | No | Pending |
```

## Error Handling

### If an Executor Fails
1. Mark the task as `Failed` in track.md
2. Review the error message
3. Attempt to fix any blocking issues
4. Retry by delegating the task again with additional context:
```bash
copilot -p "You are an Executor Agent. RETRY: Convert the root-level argument '{path}' from azurerm_orchestrated_virtual_machine_scale_set to azapi_resource. Previous attempt failed. Read track.md for context and executor.md for instructions. Task #{number}." --allow-all-tools
```

If an executor fails twice, stop the migration, write down a descripiton in `error.md`, then exit.

## Completion Criteria

The conversion project is complete when:
- ✅ All tasks in track.md show `Status: Completed`
- ✅ The `azapi.tf` file exists and contains the full `azapi_resource` block
- ✅ A `moved` block has been created in `azapi.tf`
- ✅ No tasks show `Status: Failed` or `Status: In Progress`

## Final Steps

After all conversions are complete (when delegated by Coordinator), create moved block, like:

```hcl
moved {
  from = azurerm_orchestrated_virtual_machine_scale_set.virtual_machine_scale_set
  to   = azapi_resource.virtual_machine_scale_set
}
```

Then:

1. Verify the `azapi.tf` file is syntactically correct
2. Ensure the original `main.tf` resource remains unchanged
3. Report completion to the human user
4. Wait for human review and approval


## Summary of Key Principles

1. **Root-level Arguments** → Delegate individually
2. **Root-level Blocks** → Delegate as whole unit (Executor handles nested Arguments)
3. **Nested Blocks within Blocks** → Executor recursively delegates to new Executors
4. **Status Updates** → Only modify the `Status` column in track.md
5. **Sequential Processing** → Handle tasks one at a time, in order
6. **No Parallel Execution** → Wait for each task to complete before starting the next
