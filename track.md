# Conversion Plan: azurerm_orchestrated_virtual_machine_scale_set to azapi_resource

## Resource Identification

**Source Resource**: `azurerm_orchestrated_virtual_machine_scale_set`

**Target AzAPI Resource Type**: `Microsoft.Compute/virtualMachineScaleSets@2024-11-01`

### Evidence from Provider Source Code

From the `resourceOrchestratedVirtualMachineScaleSetCreate` function in the azurerm provider:

```go
import (
	"github.com/hashicorp/go-azure-sdk/resource-manager/compute/2024-11-01/virtualmachinescalesets"
)
```

And the resource creation call:

```go
props := virtualmachinescalesets.VirtualMachineScaleSet{
	Location: location.Normalize(d.Get("location").(string)),
	Tags:     tags.Expand(t),
	Properties: &virtualmachinescalesets.VirtualMachineScaleSetProperties{
		PlatformFaultDomainCount: pointer.To(int64(d.Get("platform_fault_domain_count").(int))),
		OrchestrationMode: pointer.To(virtualmachinescalesets.OrchestrationModeFlexible),
	},
}
```

This confirms the resource type is `Microsoft.Compute/virtualMachineScaleSets` using API version `2024-11-01` with `OrchestrationMode` set to `Flexible`.

## Conversion Instructions

1. **Target File**: All new code (azapi_resource block and moved block) will be created in a new file named `azapi.tf`.
2. **Original Resource**: The executor agent MUST NOT delete or modify the original `azurerm_orchestrated_virtual_machine_scale_set` block in `main.tf`.
3. **Resource Move**: A `moved` block must be generated to transition from the azurerm resource to the azapi resource.

## Planning Task List

| No. | Path | Type | Required | Status |
|-----|------|------|----------|--------|
| 1 | name | Argument | Yes | Pending |
| 2 | resource_group_name | Argument | Yes | Pending |
| 3 | location | Argument | Yes | Pending |
| 4 | platform_fault_domain_count | Argument | Yes | Pending |
| 5 | capacity_reservation_group_id | Argument | No | Pending |
| 6 | encryption_at_host_enabled | Argument | No | Pending |
| 7 | eviction_policy | Argument | No | Pending |
| 8 | extension_operations_enabled | Argument | No | Pending |
| 9 | extensions_time_budget | Argument | No | Pending |
| 10 | instances | Argument | No | Pending |
| 11 | license_type | Argument | No | Pending |
| 12 | max_bid_price | Argument | No | Pending |
| 13 | network_api_version | Argument | No | Pending |
| 14 | priority | Argument | No | Pending |
| 15 | proximity_placement_group_id | Argument | No | Pending |
| 16 | single_placement_group | Argument | No | Pending |
| 17 | sku_name | Argument | No | Pending |
| 18 | source_image_id | Argument | No | Pending |
| 19 | tags | Argument | No | Pending |
| 20 | upgrade_mode | Argument | No | Pending |
| 21 | user_data_base64 | Argument | No | Pending |
| 22 | zone_balance | Argument | No | Pending |
| 23 | zones | Argument | No | Pending |
| 24 | additional_capabilities | Block | No | Pending |
| 25 | additional_capabilities.ultra_ssd_enabled | Argument | No | Pending |
| 26 | automatic_instance_repair | Block | No | Pending |
| 27 | automatic_instance_repair.enabled | Argument | Yes | Pending |
| 28 | automatic_instance_repair.grace_period | Argument | No | Pending |
| 29 | boot_diagnostics | Block | No | Pending |
| 30 | boot_diagnostics.storage_account_uri | Argument | No | Pending |
| 31 | data_disk | Block | No | Pending |
| 32 | data_disk.caching | Argument | Yes | Pending |
| 33 | data_disk.storage_account_type | Argument | Yes | Pending |
| 34 | data_disk.create_option | Argument | No | Pending |
| 35 | data_disk.disk_encryption_set_id | Argument | No | Pending |
| 36 | data_disk.disk_size_gb | Argument | No | Pending |
| 37 | data_disk.lun | Argument | Yes | Pending |
| 38 | data_disk.ultra_ssd_disk_iops_read_write | Argument | No | Pending |
| 39 | data_disk.ultra_ssd_disk_mbps_read_write | Argument | No | Pending |
| 40 | data_disk.write_accelerator_enabled | Argument | No | Pending |
| 41 | extension | Block | No | Pending |
| 42 | extension.name | Argument | Yes | Pending |
| 43 | extension.publisher | Argument | Yes | Pending |
| 44 | extension.type | Argument | Yes | Pending |
| 45 | extension.type_handler_version | Argument | Yes | Pending |
| 46 | extension.auto_upgrade_minor_version_enabled | Argument | No | Pending |
| 47 | extension.extensions_to_provision_after_vm_creation | Argument | No | Pending |
| 48 | extension.failure_suppression_enabled | Argument | No | Pending |
| 49 | extension.force_extension_execution_on_change | Argument | No | Pending |
| 50 | extension.protected_settings | Argument | No | Pending |
| 51 | extension.settings | Argument | No | Pending |
| 52 | extension.protected_settings_from_key_vault | Block | No | Pending |
| 53 | extension.protected_settings_from_key_vault.secret_url | Argument | Yes | Pending |
| 54 | extension.protected_settings_from_key_vault.source_vault_id | Argument | Yes | Pending |
| 55 | identity | Block | No | Pending |
| 56 | identity.type | Argument | Yes | Pending |
| 57 | identity.identity_ids | Argument | No | Pending |
| 58 | network_interface | Block | No | Pending |
| 59 | network_interface.name | Argument | Yes | Pending |
| 60 | network_interface.dns_servers | Argument | No | Pending |
| 61 | network_interface.enable_accelerated_networking | Argument | No | Pending |
| 62 | network_interface.enable_ip_forwarding | Argument | No | Pending |
| 63 | network_interface.network_security_group_id | Argument | No | Pending |
| 64 | network_interface.primary | Argument | No | Pending |
| 65 | network_interface.ip_configuration | Block | Yes | Pending |
| 66 | network_interface.ip_configuration.name | Argument | Yes | Pending |
| 67 | network_interface.ip_configuration.application_gateway_backend_address_pool_ids | Argument | No | Pending |
| 68 | network_interface.ip_configuration.application_security_group_ids | Argument | No | Pending |
| 69 | network_interface.ip_configuration.load_balancer_backend_address_pool_ids | Argument | No | Pending |
| 70 | network_interface.ip_configuration.primary | Argument | No | Pending |
| 71 | network_interface.ip_configuration.subnet_id | Argument | No | Pending |
| 72 | network_interface.ip_configuration.version | Argument | No | Pending |
| 73 | network_interface.ip_configuration.public_ip_address | Block | No | Pending |
| 74 | network_interface.ip_configuration.public_ip_address.name | Argument | Yes | Pending |
| 75 | network_interface.ip_configuration.public_ip_address.domain_name_label | Argument | No | Pending |
| 76 | network_interface.ip_configuration.public_ip_address.idle_timeout_in_minutes | Argument | No | Pending |
| 77 | network_interface.ip_configuration.public_ip_address.public_ip_prefix_id | Argument | No | Pending |
| 78 | network_interface.ip_configuration.public_ip_address.sku_name | Argument | No | Pending |
| 79 | network_interface.ip_configuration.public_ip_address.version | Argument | No | Pending |
| 80 | network_interface.ip_configuration.public_ip_address.ip_tag | Block | No | Pending |
| 81 | network_interface.ip_configuration.public_ip_address.ip_tag.tag | Argument | Yes | Pending |
| 82 | network_interface.ip_configuration.public_ip_address.ip_tag.type | Argument | Yes | Pending |
| 83 | os_disk | Block | No | Pending |
| 84 | os_disk.caching | Argument | Yes | Pending |
| 85 | os_disk.storage_account_type | Argument | Yes | Pending |
| 86 | os_disk.disk_encryption_set_id | Argument | No | Pending |
| 87 | os_disk.disk_size_gb | Argument | No | Pending |
| 88 | os_disk.write_accelerator_enabled | Argument | No | Pending |
| 89 | os_disk.diff_disk_settings | Block | No | Pending |
| 90 | os_disk.diff_disk_settings.option | Argument | Yes | Pending |
| 91 | os_disk.diff_disk_settings.placement | Argument | No | Pending |
| 92 | os_profile | Block | No | Pending |
| 93 | os_profile.custom_data | Argument | No | Pending |
| 94 | os_profile.linux_configuration | Block | No | Pending |
| 95 | os_profile.linux_configuration.admin_username | Argument | Yes | Pending |
| 96 | os_profile.linux_configuration.admin_password | Argument | No | Pending |
| 97 | os_profile.linux_configuration.computer_name_prefix | Argument | No | Pending |
| 98 | os_profile.linux_configuration.disable_password_authentication | Argument | No | Pending |
| 99 | os_profile.linux_configuration.patch_assessment_mode | Argument | No | Pending |
| 100 | os_profile.linux_configuration.patch_mode | Argument | No | Pending |
| 101 | os_profile.linux_configuration.provision_vm_agent | Argument | No | Pending |
| 102 | os_profile.linux_configuration.admin_ssh_key | Block | No | Pending |
| 103 | os_profile.linux_configuration.admin_ssh_key.public_key | Argument | Yes | Pending |
| 104 | os_profile.linux_configuration.admin_ssh_key.username | Argument | Yes | Pending |
| 105 | os_profile.linux_configuration.secret | Block | No | Pending |
| 106 | os_profile.linux_configuration.secret.key_vault_id | Argument | Yes | Pending |
| 107 | os_profile.linux_configuration.secret.certificate | Block | No | Pending |
| 108 | os_profile.linux_configuration.secret.certificate.url | Argument | Yes | Pending |
| 109 | os_profile.windows_configuration | Block | No | Pending |
| 110 | os_profile.windows_configuration.admin_password | Argument | Yes | Pending |
| 111 | os_profile.windows_configuration.admin_username | Argument | Yes | Pending |
| 112 | os_profile.windows_configuration.computer_name_prefix | Argument | No | Pending |
| 113 | os_profile.windows_configuration.enable_automatic_updates | Argument | No | Pending |
| 114 | os_profile.windows_configuration.hotpatching_enabled | Argument | No | Pending |
| 115 | os_profile.windows_configuration.patch_assessment_mode | Argument | No | Pending |
| 116 | os_profile.windows_configuration.patch_mode | Argument | No | Pending |
| 117 | os_profile.windows_configuration.provision_vm_agent | Argument | No | Pending |
| 118 | os_profile.windows_configuration.timezone | Argument | No | Pending |
| 119 | os_profile.windows_configuration.secret | Block | No | Pending |
| 120 | os_profile.windows_configuration.secret.key_vault_id | Argument | Yes | Pending |
| 121 | os_profile.windows_configuration.secret.certificate | Block | No | Pending |
| 122 | os_profile.windows_configuration.secret.certificate.store | Argument | Yes | Pending |
| 123 | os_profile.windows_configuration.secret.certificate.url | Argument | Yes | Pending |
| 124 | os_profile.windows_configuration.winrm_listener | Block | No | Pending |
| 125 | os_profile.windows_configuration.winrm_listener.protocol | Argument | Yes | Pending |
| 126 | os_profile.windows_configuration.winrm_listener.certificate_url | Argument | No | Pending |
| 127 | plan | Block | No | Pending |
| 128 | plan.name | Argument | Yes | Pending |
| 129 | plan.product | Argument | Yes | Pending |
| 130 | plan.publisher | Argument | Yes | Pending |
| 131 | priority_mix | Block | No | Pending |
| 132 | priority_mix.base_regular_count | Argument | No | Pending |
| 133 | priority_mix.regular_percentage_above_base | Argument | No | Pending |
| 134 | rolling_upgrade_policy | Block | No | Pending |
| 135 | rolling_upgrade_policy.max_batch_instance_percent | Argument | Yes | Pending |
| 136 | rolling_upgrade_policy.max_unhealthy_instance_percent | Argument | Yes | Pending |
| 137 | rolling_upgrade_policy.max_unhealthy_upgraded_instance_percent | Argument | Yes | Pending |
| 138 | rolling_upgrade_policy.pause_time_between_batches | Argument | Yes | Pending |
| 139 | rolling_upgrade_policy.cross_zone_upgrades_enabled | Argument | No | Pending |
| 140 | rolling_upgrade_policy.maximum_surge_instances_enabled | Argument | No | Pending |
| 141 | rolling_upgrade_policy.prioritize_unhealthy_instances_enabled | Argument | No | Pending |
| 142 | source_image_reference | Block | No | Pending |
| 143 | source_image_reference.offer | Argument | Yes | Pending |
| 144 | source_image_reference.publisher | Argument | Yes | Pending |
| 145 | source_image_reference.sku | Argument | Yes | Pending |
| 146 | source_image_reference.version | Argument | Yes | Pending |
| 147 | termination_notification | Block | No | Pending |
| 148 | termination_notification.enabled | Argument | Yes | Pending |
| 149 | termination_notification.timeout | Argument | No | Pending |
| 150 | sku_profile | Block | No | Pending |
| 151 | sku_profile.allocation_strategy | Argument | Yes | Pending |
| 152 | sku_profile.vm_sizes | Argument | Yes | Pending |
| 153 | timeouts | Block | No | Pending |
| 154 | timeouts.create | Argument | No | Pending |
| 155 | timeouts.delete | Argument | No | Pending |
| 156 | timeouts.read | Argument | No | Pending |
| 157 | timeouts.update | Argument | No | Pending |

## Special Considerations

### 1. OrchestrationMode
The azurerm_orchestrated_virtual_machine_scale_set resource automatically sets `OrchestrationMode` to `Flexible`. This must be explicitly set in the azapi_resource body:
```hcl
properties = {
  orchestrationMode = "Flexible"
}
```

### 2. License Type Handling
The current implementation uses `azapi_update_resource` to set `license_type` for Linux configurations. This logic needs to be incorporated into the main azapi_resource body.

### 3. Computed and Default Values
Many attributes have defaults in the azurerm provider. The executor must verify these defaults against the Azure API and handle them appropriately in the azapi_resource.

### 4. Variable References
The current resource uses various variables (e.g., `var.location`, `var.name`). The executor must preserve these references in the converted azapi_resource.

### 5. Dynamic Blocks
The azurerm resource uses many dynamic blocks for optional nested resources. The azapi_resource will need equivalent JSON/HCL structures in the body block.

### 6. Dependencies
The executor must maintain the same resource dependencies that exist in the current configuration, including references to the telemetry resource.

## Next Steps for Executor Agent

1. Create `azapi.tf` file
2. Convert the azurerm_orchestrated_virtual_machine_scale_set to azapi_resource following the task list
3. Map all Terraform schema paths to Azure API body paths
4. Handle complex nested structures (network_interface, os_profile, etc.)
5. Preserve all variable references and dynamic logic
6. Create a `moved` block to transition from azurerm to azapi
7. Ensure telemetry settings are preserved
8. Do NOT delete or modify the original azurerm resource in main.tf
