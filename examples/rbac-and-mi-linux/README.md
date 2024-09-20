<!-- BEGIN_TF_DOCS -->
# A Default Virtual Machine Scale Set with RBAC and Managed Identities Deployment

This example exercises many of the parameters available in this AVM.  It is not recommended to use this example as a template for you deployment.  Instead use this example to see examples of how to set various variables.

- a Linux VM
- a virtual network with a subnet
- a NAT gateway
- a public IP associated to the NAT gateway
- an SSH key
- locking code (commented out)
- a health extension
- availability zones
- a key vault
- passing a certificate to a VMSS

```hcl
resource "random_integer" "region_index" {
  max = length(local.test_regions) - 1
  min = 0
}

resource "random_integer" "zone_index" {
  max = length(module.regions.regions_by_name[local.test_regions[random_integer.region_index.result]].zones)
  min = 1
}

module "get_valid_sku_for_deployment_region" {
  source = "../../modules/sku_selector"

  deployment_region = local.test_regions[random_integer.region_index.result]
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  location = local.test_regions[random_integer.region_index.result]
  name     = module.naming.resource_group.name_unique
  tags     = local.tags
}
resource "azurerm_virtual_network" "this" {
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.this.location
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.this.name
  dns_servers         = ["10.0.0.4", "10.0.0.5"]
  tags                = local.tags
}
resource "azurerm_subnet" "subnet" {
  address_prefixes     = ["10.0.1.0/24"]
  name                 = module.naming.subnet.name_unique
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
}
# network security group for the subnet with a rule to allow http, https and ssh traffic
resource "azurerm_network_security_group" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.network_security_group.name_unique
  resource_group_name = azurerm_resource_group.this.name

  security_rule {
    access                     = "Allow"
    destination_address_prefix = "*"
    destination_port_range     = "80"
    direction                  = "Inbound"
    name                       = "allow-http"
    priority                   = 100
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
  }
  security_rule {
    access                     = "Allow"
    destination_address_prefix = "*"
    destination_port_range     = "443"
    direction                  = "Inbound"
    name                       = "allow-https"
    priority                   = 101
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
  }
  #ssh security rule
  security_rule {
    access                     = "Allow"
    destination_address_prefix = "*"
    destination_port_range     = "22"
    direction                  = "Inbound"
    name                       = "allow-ssh"
    priority                   = 102
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
  }
}
resource "azurerm_public_ip" "natgwpip" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.this.location
  name                = module.naming.public_ip.name_unique
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
  tags                = local.tags
  zones               = ["1", "2", "3"]
}
resource "azurerm_nat_gateway" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.nat_gateway.name_unique
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}
resource "azurerm_nat_gateway_public_ip_association" "this" {
  nat_gateway_id       = azurerm_nat_gateway.this.id
  public_ip_address_id = azurerm_public_ip.natgwpip.id
}
resource "azurerm_subnet_nat_gateway_association" "this" {
  nat_gateway_id = azurerm_nat_gateway.this.id
  subnet_id      = azurerm_subnet.subnet.id
}
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "azurerm_storage_account" "this" {
  account_replication_type = "LRS"
  account_tier             = "Standard"
  location                 = azurerm_resource_group.this.location
  name                     = module.naming.storage_account.name_unique
  resource_group_name      = azurerm_resource_group.this.name
  tags                     = local.tags
}
resource "azurerm_proximity_placement_group" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.proximity_placement_group.name_unique
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

data "azurerm_client_config" "current" {}

# This is the module call
module "terraform_azurerm_avm_res_compute_virtualmachinescaleset" {
  source = "../../"
  # source             = "Azure/avm-res-compute-virtualmachinescaleset/azurerm"
  name                        = module.naming.virtual_machine_scale_set.name_unique
  resource_group_name         = azurerm_resource_group.this.name
  enable_telemetry            = var.enable_telemetry
  location                    = azurerm_resource_group.this.location
  admin_password              = "P@ssw0rd1234!"
  sku_name                    = module.get_valid_sku_for_deployment_region.sku
  instances                   = 2
  platform_fault_domain_count = 1
  user_data_base64            = null
  admin_ssh_keys = [(
    {
      id         = tls_private_key.example_ssh.id
      public_key = tls_private_key.example_ssh.public_key_openssh
      username   = "azureuser"
    }
  )]
  network_interface = [{
    name = "VMSS-NIC"
    ip_configuration = [{
      name      = "VMSS-IPConfig"
      subnet_id = azurerm_subnet.subnet.id
    }]
  }]
  # Extensions
  extension = [{
    name                        = "CustomScriptExtension"
    publisher                   = "Microsoft.Azure.Extensions"
    type                        = "CustomScript"
    type_handler_version        = "2.0"
    auto_upgrade_minor_version  = true
    failure_suppression_enabled = false
    settings                    = "{\"commandToExecute\":\"echo 'Hello World!' \\u003e /tmp/hello.txt\"}"
    },
    {
      name                                = "HealthExtension"
      publisher                           = "Microsoft.ManagedServices"
      type                                = "ApplicationHealthLinux"
      type_handler_version                = "1.0"
      auto_upgrade_minor_version          = true
      failure_suppression_enabled         = false
      force_extension_execution_on_change = ""
      settings                            = "{\"port\":80,\"protocol\":\"http\",\"requestPath\":\"health\"}"
  }]
  # Extension protected settings
  extension_protected_setting = {
    "Custom Script Extension" = " {\r\n \"commandToExecute\": \"echo 'Protected Hello World!' \u003e /tmp/protectedhello.txt\"\r\n }\r\n"
  }
  os_profile = {
    linux_configuration = {
      disable_password_authentication = false
      user_data_base64                = base64encode(file("user-data.sh"))
      admin_username                  = "azureuser"
      admin_ssh_key                   = toset([tls_private_key.example_ssh.id])
      secret = [{
        key_vault_id = module.avm_res_keyvault_vault.resource.id
        certificate = toset([{
          url = azurerm_key_vault_certificate.example.secret_id
        }])
      }]
    }
  }
  source_image_reference = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-LTS-gen2"
    version   = "latest"
  }
  tags = local.tags
  # Uncomment the code below to implement a VMSS Lock
  #lock = {
  #  name = "VMSSNoDelete"
  #  kind = "CanNotDelete"
  #}
  depends_on = [azurerm_subnet_nat_gateway_association.this]
}
```

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.0.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (>= 3.100.0, < 4.0)

- <a name="requirement_tls"></a> [tls](#requirement\_tls) (4.0.5)

## Providers

The following providers are used by this module:

- <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) (>= 3.100.0, < 4.0)

- <a name="provider_random"></a> [random](#provider\_random)

- <a name="provider_tls"></a> [tls](#provider\_tls) (4.0.5)

## Resources

The following resources are used by this module:

- [azurerm_nat_gateway.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/nat_gateway) (resource)
- [azurerm_nat_gateway_public_ip_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/nat_gateway_public_ip_association) (resource)
- [azurerm_network_security_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) (resource)
- [azurerm_public_ip.natgwpip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) (resource)
- [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_subnet.subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_subnet_nat_gateway_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_nat_gateway_association) (resource)
- [azurerm_user_assigned_identity.example_identity](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) (resource)
- [azurerm_virtual_network.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [random_integer.region_index](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/integer) (resource)
- [random_integer.zone_index](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/integer) (resource)
- [tls_private_key.example_ssh](https://registry.terraform.io/providers/hashicorp/tls/4.0.5/docs/resources/private_key) (resource)
- [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) (data source)

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

Default: `true`

## Outputs

The following outputs are exported:

### <a name="output_location"></a> [location](#output\_location)

Description: The deployment region.

### <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name)

Description: The name of the Resource Group.

### <a name="output_virtual_machine_scale_set"></a> [virtual\_machine\_scale\_set](#output\_virtual\_machine\_scale\_set)

Description: All attributes of the Virtual Machine Scale Set resource.

### <a name="output_virtual_machine_scale_set_id"></a> [virtual\_machine\_scale\_set\_id](#output\_virtual\_machine\_scale\_set\_id)

Description: The ID of the Virtual Machine Scale Set.

### <a name="output_virtual_machine_scale_set_name"></a> [virtual\_machine\_scale\_set\_name](#output\_virtual\_machine\_scale\_set\_name)

Description: The name of the Virtual Machine Scale Set.

## Modules

The following Modules are called:

### <a name="module_get_valid_sku_for_deployment_region"></a> [get\_valid\_sku\_for\_deployment\_region](#module\_get\_valid\_sku\_for\_deployment\_region)

Source: ../../modules/sku_selector

Version:

### <a name="module_naming"></a> [naming](#module\_naming)

Source: Azure/naming/azurerm

Version: 0.4.1

### <a name="module_regions"></a> [regions](#module\_regions)

Source: Azure/regions/azurerm

Version: >= 0.4.0

### <a name="module_terraform_azurerm_avm_res_compute_virtualmachinescaleset"></a> [terraform\_azurerm\_avm\_res\_compute\_virtualmachinescaleset](#module\_terraform\_azurerm\_avm\_res\_compute\_virtualmachinescaleset)

Source: ../../

Version:

<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.
<!-- END_TF_DOCS -->