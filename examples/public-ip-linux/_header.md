# A Virtual Machine Scale Set with instance-level Public IP Addresses

This example demonstrates assigning a Public IP Address to each Virtual Machine Scale Set instance using the `public_ip_address` block, including the Public IP SKU `sku_name` and `sku_tier` fields.

- a Linux VM
- a virtual network with a subnet
- an instance-level Public IP Address per VMSS instance, using the `Standard` SKU name and `Regional` SKU tier
- an explicit `network_api_version` newer than the module default
- an SSH key
- a health extension
- availability zones

> Note: The Public IP SKU is expressed as two separate fields, matching the Azure Resource Manager API. `sku_name` accepts `Basic`, `Standard` or `StandardV2`, and `sku_tier` accepts `Regional` or `Global`. The combined `Standard_Regional` form used by the legacy `azurerm` provider is not valid here.

> Note: The `StandardV2` Public IP SKU requires `network_api_version` to be set to `2023-06-01` or later. This example uses the `Standard` SKU, which is available in every region, but sets a newer `network_api_version` to demonstrate the input.
