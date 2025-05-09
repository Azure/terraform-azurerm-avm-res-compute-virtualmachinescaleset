<!-- BEGIN_TF_DOCS -->
# terraform-azurerm-avm-res-compute-virtualmachinescaleset

Major version Zero (0.y.z) is for initial development. Anything MAY change at any time. A module SHOULD NOT be considered stable till at least it is major version one (1.0.0) or greater. Changes will always be via new versions being published and no changes will be made to existing published versions. For more details please go to https://semver.org/

> Note: This AVM will only deploy Azure Virtual Machine Scale Sets in Orchestrated mode.  Please see this reliability guidance for more information:  [Deploy VMs with flexible orchestration mode](https://learn.microsoft.com/en-us/azure/reliability/reliability-virtual-machine-scale-sets?tabs=graph-4%2Cgraph-1%2Cgraph-2%2Cgraph-3%2Cgraph-5%2Cgraph-6%2Cportal#-deploy-vms-with-flexible-orchestration-mode)

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.9, < 2.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (~> 4.26)

- <a name="requirement_modtm"></a> [modtm](#requirement\_modtm) (~> 0.3)

- <a name="requirement_random"></a> [random](#requirement\_random) (>= 3.6.2)

## Resources

The following resources are used by this module:

- [azurerm_management_lock.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_lock) (resource)
- [azurerm_orchestrated_virtual_machine_scale_set.virtual_machine_scale_set](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/orchestrated_virtual_machine_scale_set) (resource)
- [azurerm_role_assignment.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) (resource)
- [modtm_telemetry.telemetry](https://registry.terraform.io/providers/Azure/modtm/latest/docs/resources/telemetry) (resource)
- [random_uuid.telemetry](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/uuid) (resource)
- [azurerm_client_config.telemetry](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) (data source)
- [modtm_module_source.telemetry](https://registry.terraform.io/providers/Azure/modtm/latest/docs/data-sources/module_source) (data source)

<!-- markdownlint-disable MD013 -->
## Required Inputs

The following input variables are required:

### <a name="input_extension_protected_setting"></a> [extension\_protected\_setting](#input\_extension\_protected\_setting)

Description: (Optional) A JSON String which specifies Sensitive Settings (such as Passwords) for the Extension.

Type: `map(string)`

### <a name="input_location"></a> [location](#input\_location)

Description: (Required) The Azure location where the Orchestrated Virtual Machine Scale Set should exist. Changing this forces a new resource to be created.

Type: `string`

### <a name="input_name"></a> [name](#input\_name)

Description: (Required) The name of the Orchestrated Virtual Machine Scale Set. Changing this forces a new resource to be created.

Type: `string`

### <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name)

Description: (Required) The name of the Resource Group in which the Orchestrated Virtual Machine Scale Set should exist. Changing this forces a new resource to be created.

Type: `string`

### <a name="input_user_data_base64"></a> [user\_data\_base64](#input\_user\_data\_base64)

Description: (Optional) The Base64-Encoded User Data which should be used for this Virtual Machine Scale Set.

Type: `string`

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_additional_capabilities"></a> [additional\_capabilities](#input\_additional\_capabilities)

Description: - `ultra_ssd_enabled` - (Optional) Should the capacity to enable Data Disks of the `UltraSSD_LRS` storage account type be supported on this Orchestrated Virtual Machine Scale Set? Defaults to `false`. Changing this forces a new resource to be created.

Type:

```hcl
object({
    ultra_ssd_enabled = optional(bool)
  })
```

Default: `null`

### <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password)

Description: (Optional) Sets the VM password

Type: `string`

Default: `null`

### <a name="input_admin_ssh_keys"></a> [admin\_ssh\_keys](#input\_admin\_ssh\_keys)

Description: (Optional) SSH Keys to be used for Linx instances
- Unique id.  Referenced in the `os_profile` below
- (Required) The Public Key which should be used for authentication, which needs to be at least 2048-bit and in ssh-rsa format.
- (Required) The Username for which this Public SSH Key should be configured.

Type:

```hcl
set(object({
    id         = string
    public_key = string
    username   = string
  }))
```

Default: `null`

### <a name="input_automatic_instance_repair"></a> [automatic\_instance\_repair](#input\_automatic\_instance\_repair)

Description: Description: Enabling automatic instance repair allows VMSS to automatically detect and recover unhealthy VM instances at runtime, ensuring high application availability

> Note: To enable the `automatic_instance_repair`, the Orchestrated Virtual Machine Scale Set must have a valid `health_probe_id` or an [Application Health Extension](https://docs.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-health-extension).  Defaulted to true as per this reliability recommendation: [Enable automatic repair policy](https://learn.microsoft.com/en-us/azure/reliability/reliability-virtual-machine-scale-sets?tabs=graph-4%2Cgraph-1%2Cgraph-2%2Cgraph-3%2Cgraph-5%2Cgraph-6%2Cportal#-enable-automatic-repair-policy)

 - `enabled` - (Required) Should the automatic instance repair be enabled on this Orchestrated Virtual Machine Scale Set? Possible values are `true` and `false`.
 - `grace_period` - (Optional) Amount of time for which automatic repairs will be delayed. The grace period starts right after the VM is found unhealthy. Possible values are between `30` and `90` minutes. The time duration should be specified in `ISO 8601` format (e.g. `PT30M` to `PT90M`). Defaults to `PT30M`.

Type:

```hcl
object({
    enabled      = bool
    grace_period = optional(string)
  })
```

Default:

```json
{
  "enabled": true,
  "grace_period": "PT30M"
}
```

### <a name="input_boot_diagnostics"></a> [boot\_diagnostics](#input\_boot\_diagnostics)

Description: - `storage_account_uri` - (Optional) The Primary/Secondary Endpoint for the Azure Storage Account which should be used to store Boot Diagnostics, including Console Output and Screenshots from the Hypervisor. By including a `boot_diagnostics` block without passing the `storage_account_uri` field will cause the API to utilize a Managed Storage Account to store the Boot Diagnostics output.

Type:

```hcl
object({
    storage_account_uri = optional(string)
  })
```

Default: `null`

### <a name="input_capacity_reservation_group_id"></a> [capacity\_reservation\_group\_id](#input\_capacity\_reservation\_group\_id)

Description: (Optional) Specifies the ID of the Capacity Reservation Group which the Virtual Machine Scale Set should be allocated to. Changing this forces a new resource to be created.

> Note: `capacity_reservation_group_id` cannot be specified with `proximity_placement_group_id`.  If `capacity_reservation_group_id` is specified the `single_placement_group` must be set to false.

Type: `string`

Default: `null`

### <a name="input_data_disk"></a> [data\_disk](#input\_data\_disk)

Description:  - `caching` - (Required) The type of Caching which should be used for this Data Disk. Possible values are None, ReadOnly and ReadWrite.
 - `create_option` - (Optional) The create option which should be used for this Data Disk. Possible values are Empty and FromImage. Defaults to `Empty`. (FromImage should only be used if the source image includes data disks).
 - `disk_encryption_set_id` - (Optional) The ID of the Disk Encryption Set which should be used to encrypt the Data Disk. Changing this forces a new resource to be created.

> Note: Disk Encryption Sets are in Public Preview in a limited set of regions.

 - `disk_size_gb` - (Optional) The size of the Data Disk which should be created.
 - `lun` - (Optional) The Logical Unit Number of the Data Disk, which must be unique within the Virtual Machine.
 - `storage_account_type` - (Required) The Type of Storage Account which should back this Data Disk. Possible values include `Standard_LRS`, `StandardSSD_LRS`, `StandardSSD_ZRS`, `Premium_LRS`, `PremiumV2_LRS`, `Premium_ZRS` and `UltraSSD_LRS`.
 - `ultra_ssd_disk_iops_read_write` - (Optional) Specifies the Read-Write IOPS for this Data Disk. Only settable when `storage_account_type` is `PremiumV2_LRS` or `UltraSSD_LRS`.
 - `ultra_ssd_disk_mbps_read_write` - (Optional) Specifies the bandwidth in MB per second for this Data Disk. Only settable when `storage_account_type` is `PremiumV2_LRS` or `UltraSSD_LRS`.
 - `write_accelerator_enabled` - (Optional) Specifies if Write Accelerator is enabled on the Data Disk. Defaults to `false`.

Type:

```hcl
set(object({
    caching                        = string
    create_option                  = optional(string)
    disk_encryption_set_id         = optional(string)
    disk_size_gb                   = optional(number)
    lun                            = optional(number)
    storage_account_type           = string
    ultra_ssd_disk_iops_read_write = optional(number)
    ultra_ssd_disk_mbps_read_write = optional(number)
    write_accelerator_enabled      = optional(bool)
  }))
```

Default: `null`

### <a name="input_enable_telemetry"></a> [enable\_telemetry](#input\_enable\_telemetry)

Description: -> This is a Note  
This variable controls whether or not telemetry is enabled for the module.  
For more information see https://aka.ms/avm/telemetryinfo.  
If it is set to false, then no telemetry will be collected.

Type: `bool`

Default: `true`

### <a name="input_encryption_at_host_enabled"></a> [encryption\_at\_host\_enabled](#input\_encryption\_at\_host\_enabled)

Description: (Optional) Should disks attached to this Virtual Machine Scale Set be encrypted by enabling Encryption at Host?.

Type: `bool`

Default: `null`

### <a name="input_eviction_policy"></a> [eviction\_policy](#input\_eviction\_policy)

Description: (Optional) The Policy which should be used Virtual Machines are Evicted from the Scale Set. Possible values are `Deallocate` and `Delete`. Changing this forces a new resource to be created.

Type: `string`

Default: `null`

### <a name="input_extension"></a> [extension](#input\_extension)

Description:  - `auto_upgrade_minor_version_enabled` - (Optional) Should the latest version of the Extension be used at Deployment Time, if one is available? This won't auto-update the extension on existing installation. Defaults to `true`.
 - `extensions_to_provision_after_vm_creation` - (Optional) An set of Extension names which Orchestrated Virtual Machine Scale Set should provision after VM creation.
 - `failure_suppression_enabled` - (Optional) Should failures from the extension be suppressed? Possible values are `true` or `false`.

> Note: Operational failures such as not connecting to the VM will not be suppressed regardless of the `failure_suppression_enabled` value.

 - `force_extension_execution_on_change` - (Optional) A value which, when different to the previous value can be used to force-run the Extension even if the Extension Configuration hasn't changed.
 - `name` - (Required) The name for the Virtual Machine Scale Set Extension.

 > Note: Keys within the `protected_settings` block are notoriously case-sensitive, where the casing required (e.g. TitleCase vs snakeCase) depends on the Extension being used. Please refer to the documentation for the specific Orchestrated Virtual Machine Extension you're looking to use for more information.

 - `publisher` - (Required) Specifies the Publisher of the Extension.
 - `settings` - (Optional) A JSON String which specifies Settings for the Extension.
 - `type` - (Required) Specifies the Type of the Extension.
 - `type_handler_version` - (Required) Specifies the version of the extension to use, available versions can be found using the Azure CLI.

 ---
 `protected_settings_from_key_vault` block supports the following:
 - `secret_url` - (Required) The URL to the Key Vault Secret which stores the protected settings.
 - `source_vault_id` - (Required) The ID of the source Key Vault.

A Health Extension is deployed by default as per [WAF guidelines](https://learn.microsoft.com/en-us/azure/reliability/reliability-virtual-machine-scale-sets?tabs=graph-4%2Cgraph-1%2Cgraph-2%2Cgraph-3%2Cgraph-5%2Cgraph-6%2Cportal#monitoring).

> Note: `protected_settings_from_key_vault` cannot be used with `protected_settings`

Type:

```hcl
set(object({
    auto_upgrade_minor_version_enabled        = optional(bool)
    extensions_to_provision_after_vm_creation = optional(set(string))
    failure_suppression_enabled               = optional(bool)
    force_extension_execution_on_change       = optional(string)
    name                                      = string
    publisher                                 = string
    settings                                  = optional(string)
    type                                      = string
    type_handler_version                      = string
    protected_settings_from_key_vault = optional(object({
      secret_url      = string
      source_vault_id = string
    }), null)
  }))
```

Default: `null`

### <a name="input_extension_operations_enabled"></a> [extension\_operations\_enabled](#input\_extension\_operations\_enabled)

Description: > Note: `extension_operations_enabled` may only be set to `false` if there are no extensions defined in the `extension` field.
(Optional) Should extension operations be allowed on the Virtual Machine Scale Set? Possible values are `true` or `false`. Defaults to `true`. Changing this forces a new Orchestrated Virtual Machine Scale Set to be created.

Type: `bool`

Default: `null`

### <a name="input_extensions_time_budget"></a> [extensions\_time\_budget](#input\_extensions\_time\_budget)

Description: (Optional) Specifies the time alloted for all extensions to start. The time duration should be between 15 minutes and 120 minutes (inclusive) and should be specified in ISO 8601 format. Defaults to `PT1H30M`.

Type: `string`

Default: `null`

### <a name="input_instances"></a> [instances](#input\_instances)

Description: (Optional) The number of Virtual Machines in the Orcestrated Virtual Machine Scale Set.

Type: `number`

Default: `null`

### <a name="input_license_type"></a> [license\_type](#input\_license\_type)

Description: (Optional) Specifies the type of on-premise license (also known as Azure Hybrid Use Benefit) which should be used for this Orchestrated Virtual Machine Scale Set. Possible values are `None`, `Windows_Client` and `Windows_Server`.

Type: `string`

Default: `null`

### <a name="input_lock"></a> [lock](#input\_lock)

Description:   Controls the Resource Lock configuration for this resource. The following properties can be specified:

  - `kind` - (Required) The type of lock. Possible values are `\"CanNotDelete\"` and `\"ReadOnly\"`.
  - `name` - (Optional) The name of the lock. If not specified, a name will be generated based on the `kind` value. Changing this forces the creation of a new resource.

Type:

```hcl
object({
    kind = string
    name = optional(string, null)
  })
```

Default: `null`

### <a name="input_managed_identities"></a> [managed\_identities](#input\_managed\_identities)

Description: Controls the Managed Identity configuration on this resource. The following properties can be specified:

- `user_assigned_resource_ids` - (Optional) Specifies a list of User Assigned Managed Identity resource IDs to be assigned to this resource.

Type:

```hcl
object({
    system_assigned            = optional(bool, false)
    user_assigned_resource_ids = optional(set(string), [])
  })
```

Default: `{}`

### <a name="input_max_bid_price"></a> [max\_bid\_price](#input\_max\_bid\_price)

Description: (Optional) The maximum price you're willing to pay for each Orchestrated Virtual Machine in this Scale Set, in US Dollars; which must be greater than the current spot price. If this bid price falls below the current spot price the Virtual Machines in the Scale Set will be evicted using the eviction\_policy. Defaults to `-1`, which means that each Virtual Machine in the Orchestrated Scale Set should not be evicted for price reasons.  See this reference for more details: [Pricing](https://learn.microsoft.com/en-us/azure/virtual-machines/spot-vms#pricing)

Type: `number`

Default: `-1`

### <a name="input_network_interface"></a> [network\_interface](#input\_network\_interface)

Description:  - `dns_servers` - (Optional) A set of IP Addresses of DNS Servers which should be assigned to the Network Interface.
 - `enable_accelerated_networking` - (Optional) Does this Network Interface support Accelerated Networking? Possible values are `true` and `false`. Defaults to `false`.
 - `enable_ip_forwarding` - (Optional) Does this Network Interface support IP Forwarding? Possible values are `true` and `false`. Defaults to `false`.
 - `name` - (Required) The Name which should be used for this Network Interface. Changing this forces a new resource to be created.
 - `network_security_group_id` - (Optional) The ID of a Network Security Group which should be assigned to this Network Interface.
 - `primary` - (Optional) Is this the Primary IP Configuration? Possible values are `true` and `false`. Defaults to `false`.

 ---
 `ip_configuration` block supports the following:
 - `application_gateway_backend_address_pool_ids` - (Optional) A set of Backend Address Pools IDs from a Application Gateway which this Orchestrated Virtual Machine Scale Set should be connected to.
 - `application_security_group_ids` - (Optional) A set of Application Security Group IDs which this Orchestrated Virtual Machine Scale Set should be connected to.
 - `load_balancer_backend_address_pool_ids` - (Optional) A set of Backend Address Pools IDs from a Load Balancer which this Orchestrated Virtual Machine Scale Set should be connected to.

> Note: When using this field you'll also need to configure a Rule for the Load Balancer, and use a depends\_on between this resource and the Load Balancer Rule.

 - `name` - (Required) The Name which should be used for this IP Configuration.
 - `primary` - (Optional) Is this the Primary IP Configuration for this Network Interface? Possible values are `true` and `false`. Defaults to `false`.

 > Note: One `ip_configuration` block must be marked as Primary for each Network Interface.

 - `subnet_id` - (Optional) The ID of the Subnet which this IP Configuration should be connected to.

> Note: `subnet_id` is required if version is set to `IPv4`.

 - `version` - (Optional) The Internet Protocol Version which should be used for this IP Configuration. Possible values are `IPv4` and `IPv6`. Defaults to `IPv4`.

 ---
 `public_ip_address` block supports the following:
 - `domain_name_label` - (Optional) The Prefix which should be used for the Domain Name Label for each Virtual Machine Instance. Azure concatenates the Domain Name Label and Virtual Machine Index to create a unique Domain Name Label for each Virtual Machine. Valid values must be between `1` and `26` characters long, start with a lower case letter, end with a lower case letter or number and contains only `a-z`, `0-9` and `hyphens`.
 - `idle_timeout_in_minutes` - (Optional) The Idle Timeout in Minutes for the Public IP Address. Possible values are in the range `4` to `32`.
 - `name` - (Required) The Name of the Public IP Address Configuration.
 - `public_ip_prefix_id` - (Optional) The ID of the Public IP Address Prefix from where Public IP Addresses should be allocated. Changing this forces a new resource to be created.
 - `sku_name` - (Optional) Specifies what Public IP Address SKU the Public IP Address should be provisioned as. Possible vaules include `Basic_Regional`, `Basic_Global`, `Standard_Regional` or `Standard_Global`. For more information about Public IP Address SKU's and their capabilities, please see the [product documentation](https://docs.microsoft.com/azure/virtual-network/ip-services/public-ip-addresses#sku). Changing this forces a new resource to be created.
 - `version` - (Optional) The Internet Protocol Version which should be used for this public IP address. Possible values are `IPv4` and `IPv6`. Defaults to `IPv4`. Changing this forces a new resource to be created.

 ---
 `ip_tag` block supports the following:
 - `tag` - (Required) The IP Tag associated with the Public IP, such as `SQL` or `Storage`. Changing this forces a new resource to be created.
 - `type` - (Required) The Type of IP Tag, such as `FirstPartyUsage`. Changing this forces a new resource to be created.

Type:

```hcl
set(object({
    dns_servers                   = optional(set(string))
    enable_accelerated_networking = optional(bool)
    enable_ip_forwarding          = optional(bool)
    name                          = string
    network_security_group_id     = optional(string)
    primary                       = optional(bool)
    ip_configuration = set(object({
      application_gateway_backend_address_pool_ids = optional(set(string))
      application_security_group_ids               = optional(set(string))
      load_balancer_backend_address_pool_ids       = optional(set(string))
      name                                         = string
      primary                                      = optional(bool)
      subnet_id                                    = optional(string)
      version                                      = optional(string)
      public_ip_address = optional(set(object({
        domain_name_label       = optional(string)
        idle_timeout_in_minutes = optional(number)
        name                    = string
        public_ip_prefix_id     = optional(string)
        sku_name                = optional(string)
        version                 = optional(string)
        ip_tag = optional(set(object({
          tag  = string
          type = string
        })))
      })))
    }))
  }))
```

Default: `null`

### <a name="input_os_disk"></a> [os\_disk](#input\_os\_disk)

Description: - `caching` - (Required) The Type of Caching which should be used for the Internal OS Disk. Possible values are `None`, `ReadOnly` and `ReadWrite`.
- `disk_encryption_set_id` - (Optional) The ID of the Disk Encryption Set which should be used to encrypt this OS Disk. Changing this forces a new resource to be created.
- `disk_size_gb` - (Optional) The Size of the Internal OS Disk in GB, if you wish to vary from the size used in the image this Virtual Machine Scale Set is sourced from.
- `storage_account_type` - (Required) The Type of Storage Account which should back this the Internal OS Disk. Possible values include `Standard_LRS`, `StandardSSD_LRS`, `StandardSSD_ZRS`, `Premium_LRS` and `Premium_ZRS`. Changing this forces a new resource to be created.
- `write_accelerator_enabled` - (Optional) Specifies if Write Accelerator is enabled on the OS Disk. Defaults to `false`.

---
`diff_disk_settings` block supports the following:
- `option` - (Required) Specifies the Ephemeral Disk Settings for the OS Disk. At this time the only possible value is `Local`. Changing this forces a new resource to be created.
- `placement` - (Optional) Specifies where to store the Ephemeral Disk. Possible values are `CacheDisk` and `ResourceDisk`. Defaults to `CacheDisk`. Changing this forces a new resource to be created.

Type:

```hcl
object({
    caching                   = string
    disk_encryption_set_id    = optional(string)
    disk_size_gb              = optional(number)
    storage_account_type      = string
    write_accelerator_enabled = optional(bool)
    diff_disk_settings = optional(object({
      option    = string
      placement = optional(string)
    }))
  })
```

Default:

```json
{
  "caching": "ReadWrite",
  "storage_account_type": "Premium_LRS"
}
```

### <a name="input_os_profile"></a> [os\_profile](#input\_os\_profile)

Description: Configure the operating system provile.

 - `custom_data` - (Optional) The Base64-Encoded Custom Data which should be used for this Orchestrated Virtual Machine Scale Set.

 > Note: When Custom Data has been configured, it's not possible to remove it without tainting the Orchestrated Virtual Machine Scale Set, due to a limitation of the Azure API.

 ---
 `linux_configuration` block supports the following:
 - `admin_username` - (Required) The username of the local administrator on each Orchestrated Virtual Machine Scale Set instance. Changing this forces a new resource to be created.
 - `computer_name_prefix` - (Optional) The prefix which should be used for the name of the Virtual Machines in this Scale Set. If unspecified this defaults to the value for the name field. If the value of the name field is not a valid `computer_name_prefix`, then you must specify `computer_name_prefix`. Changing this forces a new resource to be created.
 - `disable_password_authentication` - (Optional) When an `admin_password` is specified `disable_password_authentication` must be set to `false`. Defaults to `true`.

> Note: Either `admin_password` or `admin_ssh_key` must be specified.

 - `patch_assessment_mode` - (Optional) Specifies the mode of VM Guest Patching for the virtual machines that are associated to the Orchestrated Virtual Machine Scale Set. Possible values are `AutomaticByPlatform` or `ImageDefault`. Defaults to `AutomaticByPlatform`.

> Note: If the `patch_assessment_mode` is set to `AutomaticByPlatform` then the `provision_vm_agent` field must be set to true.

 - `patch_mode` - (Optional) Specifies the mode of in-guest patching of this Windows Virtual Machine. Possible values are `ImageDefault` or `AutomaticByPlatform`. Defaults to `AutomaticByPlatform`. For more information on patch modes please see the [product documentation](https://docs.microsoft.com/azure/virtual-machines/automatic-vm-guest-patching#patch-orchestration-modes).

> Note: If `patch_mode` is set to `AutomaticByPlatform` the `provision_vm_agent` must be set to `true` and the `extension` must contain at least one application health extension.

 - `provision_vm_agent` - (Optional) Should the Azure VM Agent be provisioned on each Virtual Machine in the Scale Set? Defaults to `true`. Changing this value forces a new resource to be created.

 ---
 `admin_ssh_key_id` Set of ids which reference the `admin_ssh_keys` sensitive variable

 > Note: The Azure VM Agent only allows creating SSH Keys at the path `/home/{username}/.ssh/authorized_keys` - as such this public key will be written to the authorized keys file.

 ---
 `secret` block supports the following:
 - `key_vault_id` - (Required) The ID of the Key Vault from which all Secrets should be sourced.

 ---
 `certificate` block supports the following:
 - `url` - (Required) The Secret URL of a Key Vault Certificate.

 > Note: The schema of the `certificate block` is slightly different depending on if you are provisioning a `windows_configuration` or a `linux_configuration`.

---
 `windows_configuration` block supports the following:
 - `admin_username` - (Required) The username of the local administrator on each Orchestrated Virtual Machine Scale Set instance. Changing this forces a new resource to be created.
 - `computer_name_prefix` - (Optional) The prefix which should be used for the name of the Virtual Machines in this Scale Set. If unspecified this defaults to the value for the `name` field. If the value of the `name` field is not a valid `computer_name_prefix`, then you must specify `computer_name_prefix`. Changing this forces a new resource to be created.
 - `enable_automatic_updates` - (Optional) Are automatic updates enabled for this Virtual Machine? Defaults to `false`.
 - `hotpatching_enabled` - (Optional) Should the VM be patched without requiring a reboot? Possible values are `true` or `false`. Defaults to `false`. For more information about hot patching please see the [product documentation](https://docs.microsoft.com/azure/automanage/automanage-hotpatch).

> Note: Hotpatching can only be enabled if the `patch_mode` is set to `AutomaticByPlatform`, the `provision_vm_agent` is set to `true`, your `source_image_reference` references a hotpatching enabled image, the VM's `sku_name` is set to a [Azure generation 2](https://docs.microsoft.com/azure/virtual-machines/generation-2#generation-2-vm-sizes) VM SKU and the `extension` contains an application health extension.

 - `patch_assessment_mode` - (Optional) Specifies the mode of VM Guest Patching for the virtual machines that are associated to the Orchestrated Virtual Machine Scale Set. Possible values are `AutomaticByPlatform` or `ImageDefault`. Defaults to `ImageDefault`.

> Note: If the `patch_assessment_mode` is set to `AutomaticByPlatform` then the `provision_vm_agent` field must be set to `true`.

 - `patch_mode` - (Optional) Specifies the mode of in-guest patching of this Windows Virtual Machine. Possible values are `Manual`, `AutomaticByOS` and `AutomaticByPlatform`. Defaults to `AutomaticByOS`. For more information on patch modes please see the [product documentation](https://docs.microsoft.com/azure/virtual-machines/automatic-vm-guest-patching#patch-orchestration-modes).

> Note: If `patch_mode` is set to `AutomaticByPlatform` the `provision_vm_agent` must be set to `true` and the `extension` must contain at least one application health extension.

 - `provision_vm_agent` - (Optional) Should the Azure VM Agent be provisioned on each Virtual Machine in the Scale Set? Defaults to `true`. Changing this value forces a new resource to be created.
 - `timezone` - (Optional) Specifies the time zone of the virtual machine, the possible values are defined [here](https://jackstromberg.com/2017/01/list-of-time-zones-consumed-by-azure/).

 ---
 `secret` block supports the following:
 - `key_vault_id` - (Required) The ID of the Key Vault from which all Secrets should be sourced.

 ---
 `certificate` block supports the following:
 - `store` - (Required) The certificate store on the Virtual Machine where the certificate should be added.
 - `url` - (Required) The Secret URL of a Key Vault Certificate.

 ---
 `winrm_listener` block supports the following:
 - `certificate_url` - (Optional) The Secret URL of a Key Vault Certificate, which must be specified when protocol is set to `Https`. Changing this forces a new resource to be created.
 - `protocol` - (Required) Specifies the protocol of listener. Possible values are `Http` or `Https`. Changing this forces a new resource to be created.

> Note: This can be sourced from the `secret_id` field within the `azurerm_key_vault_certificate` Resource.

Type:

```hcl
object({
    custom_data = optional(string)
    linux_configuration = optional(object({
      admin_username                  = string
      computer_name_prefix            = optional(string)
      disable_password_authentication = optional(bool)
      patch_assessment_mode           = optional(string)
      patch_mode                      = optional(string, "AutomaticByPlatform")
      provision_vm_agent              = optional(bool, true)
      admin_ssh_key_id                = optional(set(string))
      secret = optional(set(object({
        key_vault_id = string
        certificate = set(object({
          url = string
        }))
      })))
    }))
    windows_configuration = optional(object({
      admin_username           = string
      computer_name_prefix     = optional(string)
      enable_automatic_updates = optional(bool, false)
      hotpatching_enabled      = optional(bool)
      patch_assessment_mode    = optional(string)
      patch_mode               = optional(string, "AutomaticByPlatform")
      provision_vm_agent       = optional(bool, true)
      timezone                 = optional(string)
      secret = optional(set(object({
        key_vault_id = string
        certificate = set(object({
          store = string
          url   = string
        }))
      })))
      winrm_listener = optional(set(object({
        certificate_url = optional(string)
        protocol        = string
      })))
    }))
  })
```

Default: `null`

### <a name="input_plan"></a> [plan](#input\_plan)

Description: - `name` - (Required) Specifies the name of the image from the marketplace. Changing this forces a new resource to be created.
- `product` - (Required) Specifies the product of the image from the marketplace. Changing this forces a new resource to be created.
- `publisher` - (Required) Specifies the publisher of the image. Changing this forces a new resource to be created.

Type:

```hcl
object({
    name      = string
    product   = string
    publisher = string
  })
```

Default: `null`

### <a name="input_platform_fault_domain_count"></a> [platform\_fault\_domain\_count](#input\_platform\_fault\_domain\_count)

Description: (Required) Specifies the number of fault domains that are used by this Orchestrated Virtual Machine Scale Set. Changing this forces a new resource to be created.  Setting to 1 enables Max Spreading.  [Spreading options](https://learn.microsoft.com/en-us/azure/reliability/reliability-virtual-machine-scale-sets?tabs=graph-4%2Cgraph-1%2Cgraph-2%2Cgraph-3%2Cgraph-5%2Cgraph-6%2Cportal#spreading-options)

Type: `number`

Default: `1`

### <a name="input_priority"></a> [priority](#input\_priority)

Description: (Optional) The Priority of this Orchestrated Virtual Machine Scale Set. Possible values are `Regular` and `Spot`. Defaults to `Regular`. Changing this value forces a new resource.

Type: `string`

Default: `"Regular"`

### <a name="input_priority_mix"></a> [priority\_mix](#input\_priority\_mix)

Description: - `base_regular_count` - (Optional) Specifies the base number of VMs of `Regular` priority that will be created before any VMs of priority `Spot` are created. Possible values are integers between `0` and `1000`. Defaults to `0`.
- `regular_percentage_above_base` - (Optional) Specifies the desired percentage of VM instances that are of `Regular` priority after the base count has been reached. Possible values are integers between `0` and `100`. Defaults to `0`.

Type:

```hcl
object({
    base_regular_count            = optional(number)
    regular_percentage_above_base = optional(number)
  })
```

Default: `null`

### <a name="input_proximity_placement_group_id"></a> [proximity\_placement\_group\_id](#input\_proximity\_placement\_group\_id)

Description: (Optional) The ID of the Proximity Placement Group which the Orchestrated Virtual Machine should be assigned to. Changing this forces a new resource to be created.

Type: `string`

Default: `null`

### <a name="input_role_assignments"></a> [role\_assignments](#input\_role\_assignments)

Description:   A map of role assignments to create on the <RESOURCE>. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

  - `role_definition_id_or_name` - The ID or name of the role definition to assign to the principal.
  - `principal_id` - The ID of the principal to assign the role to.
  - `description` - (Optional) The description of the role assignment.
  - `skip_service_principal_aad_check` - (Optional) If set to true, skips the Azure Active Directory check for the service principal in the tenant. Defaults to false.
  - `condition` - (Optional) The condition which will be used to scope the role assignment.
  - `condition_version` - (Optional) The version of the condition syntax. Leave as `null` if you are not using a condition, if you are then valid values are '2.0'.
  - `delegated_managed_identity_resource_id` - (Optional) The delegated Azure Resource Id which contains a Managed Identity. Changing this forces a new resource to be created. This field is only used in cross-tenant scenario.
  - `principal_type` - (Optional) The type of the `principal_id`. Possible values are `User`, `Group` and `ServicePrincipal`. It is necessary to explicitly set this attribute when creating role assignments if the principal creating the assignment is constrained by ABAC rules that filters on the PrincipalType attribute.

  > Note: only set `skip_service_principal_aad_check` to true if you are assigning a role to a service principal.

Type:

```hcl
map(object({
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    principal_type                         = optional(string, null)
  }))
```

Default: `{}`

### <a name="input_single_placement_group"></a> [single\_placement\_group](#input\_single\_placement\_group)

Description: (Optional) Should this Virtual Machine Scale Set be limited to a Single Placement Group, which means the number of instances will be capped at 100 Virtual Machines. Possible values are `true` or `false`.
> Note: `single_placement_group` behaves differently for Orchestrated Virtual Machine Scale Sets than it does for other Virtual Machine Scale Sets. If you do not define the `single_placement_group` field in your configuration file the service will determin what this value should be based off of the value contained within the `sku_name` field of your configuration file. You may set the `single_placement_group` field to `true`, however once you set it to `false` you will not be able to revert it back to `true`. If you wish to use Specialty Sku virtual machines (e.g. [M-Seiries](https://docs.microsoft.com/azure/virtual-machines/m-series) virtual machines) you will need to contact you Microsoft support professional and request to be added to the include list since this feature is currently in private preview until the end of September 2022. Once you have been added to the private preview include list you will need to run the following command to register your subscription with the feature: `az feature register --namespace Microsoft.Compute --name SpecialSkusForVmssFlex`. If you are not on the include list this command will error out with the following error message `(featureRegistrationUnsupported) The feature 'SpecialSkusForVmssFlex' does not support registration`.

Type: `bool`

Default: `null`

### <a name="input_sku_name"></a> [sku\_name](#input\_sku\_name)

Description: (Optional) The `name` of the SKU to be used by this Orcestrated Virtual Machine Scale Set. Valid values include: any of the [General purpose](https://docs.microsoft.com/azure/virtual-machines/sizes-general), [Compute optimized](https://docs.microsoft.com/azure/virtual-machines/sizes-compute), [Memory optimized](https://docs.microsoft.com/azure/virtual-machines/sizes-memory), [Storage optimized](https://docs.microsoft.com/azure/virtual-machines/sizes-storage), [GPU optimized](https://docs.microsoft.com/azure/virtual-machines/sizes-gpu), [FPGA optimized](https://docs.microsoft.com/azure/virtual-machines/sizes-field-programmable-gate-arrays), [High performance](https://docs.microsoft.com/azure/virtual-machines/sizes-hpc), or [Previous generation](https://docs.microsoft.com/azure/virtual-machines/sizes-previous-gen) virtual machine SKUs.

Type: `string`

Default: `null`

### <a name="input_source_image_id"></a> [source\_image\_id](#input\_source\_image\_id)

Description: (Optional) The ID of an Image which each Virtual Machine in this Scale Set should be based on. Possible Image ID types include `Image ID`s, `Shared Image ID`s, `Shared Image Version ID`s, `Community Gallery Image ID`s, `Community Gallery Image Version ID`s, `Shared Gallery Image ID`s and `Shared Gallery Image Version ID`s.

Type: `string`

Default: `null`

### <a name="input_source_image_reference"></a> [source\_image\_reference](#input\_source\_image\_reference)

Description: - `offer` - (Required) Specifies the offer of the image used to create the virtual machines. Changing this forces a new resource to be created.
- `publisher` - (Required) Specifies the publisher of the image used to create the virtual machines. Changing this forces a new resource to be created.
- `sku` - (Required) Specifies the SKU of the image used to create the virtual machines.
- `version` - (Required) Specifies the version of the image used to create the virtual machines.

Type:

```hcl
object({
    offer     = string
    publisher = string
    sku       = string
    version   = string
  })
```

Default: `null`

### <a name="input_tags"></a> [tags](#input\_tags)

Description: (Optional) Tags of the resource.

Type: `map(string)`

Default: `null`

### <a name="input_termination_notification"></a> [termination\_notification](#input\_termination\_notification)

Description: - `enabled` - (Required) Should the termination notification be enabled on this Virtual Machine Scale Set? Possible values `true` or `false`
- `timeout` - (Optional) Length of time (in minutes, between `5` and `15`) a notification to be sent to the VM on the instance metadata server till the VM gets deleted. The time duration should be specified in `ISO 8601` format. Defaults to `PT5M`.

Type:

```hcl
object({
    enabled = bool
    timeout = optional(string)
  })
```

Default: `null`

### <a name="input_timeouts"></a> [timeouts](#input\_timeouts)

Description: - `create` - (Defaults to 60 minutes) Used when creating the Orchestrated Virtual Machine Scale Set.
- `delete` - (Defaults to 60 minutes) Used when deleting the Orchestrated Virtual Machine Scale Set.
- `read` - (Defaults to 5 minutes) Used when retrieving the Orchestrated Virtual Machine Scale Set.
- `update` - (Defaults to 60 minutes) Used when updating the Orchestrated Virtual Machine Scale Set.

Type:

```hcl
object({
    create = optional(string)
    delete = optional(string)
    read   = optional(string)
    update = optional(string)
  })
```

Default: `null`

### <a name="input_upgrade_policy"></a> [upgrade\_policy](#input\_upgrade\_policy)

Description: Defines the upgrade policy of the VMSS. Defaults to `{ upgrade_mode = "Manual" }`

- `upgrade_mode` - (Optional) Specifies how Upgrades (e.g. changing the Image/SKU) should be performed to Virtual Machine Instances. Possible values are Automatic, Manual and Rolling. Defaults to Manual.
- `rolling_upgrade_policy` - (Optional) Required if upgrade\_mode is Rolling. An object use to set rolling upgrade parameters. Defaults to null.
  - `cross_zone_upgrades_enable` - (Optional) Should the Virtual Machine Scale Set ignore the Azure Zone boundaries when constructing upgrade batches? Possible values are true or false.
  - `max_batch_instance_percent` - (Required) The maximum percent of total virtual machine instances that will be upgraded simultaneously by the rolling upgrade in one batch. As this is a maximum, unhealthy instances in previous or future batches can cause the percentage of instances in a batch to decrease to ensure higher reliability.
  - `max_unhealthy_instance_percent` - (Required) The maximum percentage of the total virtual machine instances in the scale set that can be simultaneously unhealthy, either as a result of being upgraded, or by being found in an unhealthy state by the virtual machine health checks before the rolling upgrade aborts. This constraint will be checked prior to starting any batch.
  - `max_unhealthy_upgraded_instance_percent`- (Required) The maximum percentage of upgraded virtual machine instances that can be found to be in an unhealthy state. This check will happen after each batch is upgraded. If this percentage is ever exceeded, the rolling update aborts.
  - `pause_time_between_batches`- (Required) The wait time between completing the update for all virtual machines in one batch and starting the next batch. The time duration should be specified in ISO 8601 format.
  - `prioritize_unhealthy_instances_enabled` - (Optional) Upgrade all unhealthy instances in a scale set before any healthy instances. Possible values are true or false.
  - `maximum_surge_instances_enabled`- (Required) Create new virtual machines to upgrade the scale set, rather than updating the existing virtual machines. Existing virtual machines will be deleted once the new virtual machines are created for each batch. Possible values are true or false.

Type:

```hcl
object({
    upgrade_mode = optional(string, "Manual")
    rolling_upgrade_policy = optional(object({
      cross_zone_upgrades_enabled             = optional(bool)
      max_batch_instance_percent              = optional(number)
      max_unhealthy_instance_percent          = optional(number)
      max_unhealthy_upgraded_instance_percent = optional(number)
      pause_time_between_batches              = optional(string)
      prioritize_unhealthy_instances_enabled  = optional(bool)
      maximum_surge_instances_enabled         = optional(bool)
    }), {})
  })
```

Default:

```json
{
  "upgrade_mode": "Manual"
}
```

### <a name="input_zone_balance"></a> [zone\_balance](#input\_zone\_balance)

Description: (Optional) Should the Virtual Machines in this Scale Set be strictly evenly distributed across Availability Zones? Defaults to `false`. Changing this forces a new resource to be created.

> Note: This can only be set to `true` when one or more `zones` are configured.

Type: `bool`

Default: `false`

### <a name="input_zones"></a> [zones](#input\_zones)

Description: Specifies a list of Availability Zones in which this Orchestrated Virtual Machine should be located. Changing this forces a new Orchestrated Virtual Machine to be created.  Defaulted to 3 zones as per this reliability guidance: [Deploy Virtual Machine Scale Sets across availability zones with Virtual Machine Scale Sets Flex](https://learn.microsoft.com/en-us/azure/reliability/reliability-virtual-machine-scale-sets?tabs=graph-4%2Cgraph-1%2Cgraph-2%2Cgraph-3%2Cgraph-5%2Cgraph-6%2Cportal#-deploy-virtual-machine-scale-sets-across-availability-zones-with-virtual-machine-scale-sets-flex)

> Note: Due to a limitation of the Azure API at this time only one Availability Zone can be defined.

Type: `set(string)`

Default:

```json
[
  "1",
  "2",
  "3"
]
```

## Outputs

The following outputs are exported:

### <a name="output_resource"></a> [resource](#output\_resource)

Description: All attributes of the Virtual Machine Scale Set resource.

### <a name="output_resource_id"></a> [resource\_id](#output\_resource\_id)

Description: The ID of the Virtual Machine Scale Set.

### <a name="output_resource_name"></a> [resource\_name](#output\_resource\_name)

Description: The name of the Virtual Machine Scale Set.

## Modules

No modules.

<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.
<!-- END_TF_DOCS -->