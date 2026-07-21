<!-- BEGIN_TF_DOCS -->
# Virtual Machine Scale Set with an extension using protected settings (Windows)

This example demonstrates a Windows VMSS where an extension is configured with
**protected settings** (`extension_protected_setting`), alongside another
extension that only uses public settings. The deployment includes:

- a Windows VMSS
- a virtual network with a subnet
- a NAT gateway with an associated public IP
- a CustomScript extension whose `commandToExecute` is delivered via
  `protectedSettings` (encrypted / write-only)
- an application health extension using public settings
- availability zones

It is also the regression scenario for issue #159: because the CustomScript
extension carries a protected setting, the module builds the extensions array in
both `body` and `sensitive_body`. The azapi provider merges `sensitive_body`
over `body` with RFC 7396 JSON Merge Patch (arrays are replaced wholesale), so
the module must mirror every non-sensitive property into `sensitive_body`;
otherwise the extensions would be provisioned with empty properties and the
post-apply idempotency check would fail.

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.9, < 2.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (~> 4.0)

- <a name="requirement_random"></a> [random](#requirement\_random) (~> 3.0)

## Providers

The following providers are used by this module:

- <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) (~> 4.0)

- <a name="provider_random"></a> [random](#provider\_random) (~> 3.0)

## Resources

The following resources are used by this module:

- [azurerm_nat_gateway.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/nat_gateway) (resource)
- [azurerm_nat_gateway_public_ip_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/nat_gateway_public_ip_association) (resource)
- [azurerm_network_security_group.nic](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) (resource)
- [azurerm_network_security_group.subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) (resource)
- [azurerm_public_ip.natgwpip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) (resource)
- [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_subnet.subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_subnet_nat_gateway_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_nat_gateway_association) (resource)
- [azurerm_subnet_network_security_group_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) (resource)
- [azurerm_virtual_network.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [random_integer.region_index](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/integer) (resource)
- [random_integer.zone_index](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/integer) (resource)

<!-- markdownlint-disable MD013 -->
## Required Inputs

No required inputs.

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_enable_telemetry"></a> [enable\_telemetry](#input\_enable\_telemetry)

Description: This variable controls whether or not telemetry is enabled for the module.  
For more information see https://aka.ms/avm/telemetryinfo.  
If it is set to false, then no telemetry will be collected.

Type: `bool`

Default: `false`

## Outputs

The following outputs are exported:

### <a name="output_location"></a> [location](#output\_location)

Description: The deployment region.

### <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name)

Description: The name of the Resource Group.

### <a name="output_resource_id"></a> [resource\_id](#output\_resource\_id)

Description: The ID of the Virtual Machine Scale Set

### <a name="output_virtual_machine_scale_set_id"></a> [virtual\_machine\_scale\_set\_id](#output\_virtual\_machine\_scale\_set\_id)

Description: The ID of the Virtual Machine Scale Set.

### <a name="output_virtual_machine_scale_set_name"></a> [virtual\_machine\_scale\_set\_name](#output\_virtual\_machine\_scale\_set\_name)

Description: The name of the Virtual Machine Scale Set.

## Modules

The following Modules are called:

### <a name="module_avm_ptn_ephemeral_credential"></a> [avm\_ptn\_ephemeral\_credential](#module\_avm\_ptn\_ephemeral\_credential)

Source: Azure/avm-ptn-ephemeral-credential/azure

Version: 0.1.0

### <a name="module_get_valid_sku_for_deployment_region"></a> [get\_valid\_sku\_for\_deployment\_region](#module\_get\_valid\_sku\_for\_deployment\_region)

Source: ../../modules/sku_selector

Version:

### <a name="module_naming"></a> [naming](#module\_naming)

Source: Azure/naming/azurerm

Version: 0.4.1

### <a name="module_regions"></a> [regions](#module\_regions)

Source: Azure/avm-utl-regions/azurerm

Version: 0.3.0

### <a name="module_terraform_azurerm_avm_res_compute_virtualmachinescaleset"></a> [terraform\_azurerm\_avm\_res\_compute\_virtualmachinescaleset](#module\_terraform\_azurerm\_avm\_res\_compute\_virtualmachinescaleset)

Source: ../../

Version:

<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.
<!-- END_TF_DOCS -->