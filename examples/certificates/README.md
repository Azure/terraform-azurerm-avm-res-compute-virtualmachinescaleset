<!-- BEGIN_TF_DOCS -->
# A Virtual Machine Scale Set Deployment with Certificates

This example demonstrates how to pull certificates from a Key Vault and send them to VMSS

```hcl
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.85, < 4.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.10.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.5"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see https://aka.ms/avm/telemetryinfo.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
}

# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.3.0"
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  location = "eastus"
  name     = module.naming.resource_group.name_unique
  tags = {
    scenario = "AVM VMSS Sample Certificates Deployment"
  }
}

resource "azurerm_virtual_network" "this" {
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.this.location
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.this.name
  dns_servers         = ["10.0.0.4", "10.0.0.5"]
  tags = {
    scenario = "AVM VMSS Sample Certificates Deployment"
  }
}

resource "azurerm_subnet" "subnet" {
  address_prefixes     = ["10.0.1.0/24"]
  name                 = "VMSS-Subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
}

# network security group for the subnet with a rule to allow http, https and ssh traffic
resource "azurerm_network_security_group" "myNSG" {
  location            = azurerm_resource_group.this.location
  name                = "myNSG"
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
  tags = {
    scenario = "AVM VMSS Sample Certificates Deployment"
  }
  zones = ["1", "2", "3"]
}

resource "azurerm_nat_gateway" "this" {
  location            = azurerm_resource_group.this.location
  name                = "MyNatGateway"
  resource_group_name = azurerm_resource_group.this.name
  tags = {
    scenario = "AVM VMSS Sample Certificates Deployment"
  }
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

data "azurerm_client_config" "current" {}

#create a keyvault for storing the credential with RBAC for the deployment user
module "avm_res_keyvault_vault" {
  source                 = "Azure/avm-res-keyvault-vault/azurerm"
  version                = "0.3.0"
  tenant_id              = data.azurerm_client_config.current.tenant_id
  name                   = module.naming.key_vault.name_unique
  resource_group_name    = azurerm_resource_group.this.name
  location               = azurerm_resource_group.this.location
  enabled_for_deployment = true

  network_acls = {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  role_assignments = {
    deployment_user_administrator = {
      role_definition_id_or_name = "Key Vault Certificates Officer"
      principal_id               = data.azurerm_client_config.current.object_id
    }
  }

  wait_for_rbac_before_secret_operations = {
    create = "120s"
  }

  tags = {
    scenario = "AVM VMSS Sample Certificates Deployment"
  }
}

resource "time_sleep" "wait_60_seconds" {
  create_duration = "60s"

  depends_on = [module.avm_res_keyvault_vault]
}

resource "azurerm_key_vault_certificate" "example" {
  key_vault_id = module.avm_res_keyvault_vault.resource.id
  name         = "generated-cert"
  tags = {
    scenario = "AVM VMSS Sample Certificates Deployment"
  }

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }
    key_properties {
      exportable = true
      key_type   = "RSA"
      reuse_key  = true
      key_size   = 2048
    }
    secret_properties {
      content_type = "application/x-pkcs12"
    }
    lifetime_action {
      action {
        action_type = "AutoRenew"
      }
      trigger {
        days_before_expiry = 30
      }
    }
    x509_certificate_properties {
      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
      ]
      subject            = "CN=hello-world"
      validity_in_months = 12
      # Server Authentication = 1.3.6.1.5.5.7.3.1
      # Client Authentication = 1.3.6.1.5.5.7.3.2
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"]

      subject_alternative_names {
        dns_names = ["internal.contoso.com", "domain.hello.world"]
      }
    }
  }

  depends_on = [time_sleep.wait_60_seconds]
}

# This is the module call
module "terraform-azurerm-avm-res-compute-virtualmachinescaleset" {
  source = "../../"
  # source             = "Azure/avm-res-compute-virtualmachinescaleset/azurerm"
  name                        = module.naming.virtual_machine_scale_set.name_unique
  resource_group_name         = azurerm_resource_group.this.name
  enable_telemetry            = var.enable_telemetry
  location                    = azurerm_resource_group.this.location
  platform_fault_domain_count = 1
  admin_password              = "P@ssw0rd1234!"
  instances                   = 2
  sku_name                    = "Standard_D2s_v4"
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
  os_profile = {
    linux_configuration = {
      disable_password_authentication = false
      user_data_base64                = base64encode(file("user-data.sh"))
      admin_username                  = "azureuser"
      admin_ssh_key                   = toset([tls_private_key.example_ssh.id])
      provision_vm_agent              = true
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
  extension = [{
    name                       = "HealthExtension"
    publisher                  = "Microsoft.ManagedServices"
    type                       = "ApplicationHealthLinux"
    type_handler_version       = "1.0"
    auto_upgrade_minor_version = true
    settings                   = <<SETTINGS
      {
        "protocol": "http",
        "port" : 80,
        "requestPath": "health"
      }
  SETTINGS
  }]
  tags = {
    scenario = "AVM VMSS Sample Certificates Deployment"
  }
  depends_on = [azurerm_subnet_nat_gateway_association.this]
}

output "location" {
  value       = azurerm_resource_group.this.location
  description = "The deployment region."
}

output "resource_group_name" {
  value       = azurerm_resource_group.this.name
  description = "The name of the Resource Group."
}

output "virtual_machine_scale_set_id" {
  value       = module.terraform-azurerm-avm-res-compute-virtualmachinescaleset.resource_id
  description = "The ID of the Virtual Machine Scale Set."
}

output "virtual_machine_scale_set_name" {
  value       = module.terraform-azurerm-avm-res-compute-virtualmachinescaleset.resource_name
  description = "The name of the Virtual Machine Scale Set."
}

output "virtual_machine_scale_set" {
  value       = module.terraform-azurerm-avm-res-compute-virtualmachinescaleset.resource
  sensitive   = true
  description = "All attributes of the Virtual Machine Scale Set resource."
}
```

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.0.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (>= 3.85, < 4.0)

- <a name="requirement_time"></a> [time](#requirement\_time) (0.10.0)

- <a name="requirement_tls"></a> [tls](#requirement\_tls) (4.0.5)

## Providers

The following providers are used by this module:

- <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) (>= 3.85, < 4.0)

- <a name="provider_time"></a> [time](#provider\_time) (0.10.0)

- <a name="provider_tls"></a> [tls](#provider\_tls) (4.0.5)

## Resources

The following resources are used by this module:

- [azurerm_key_vault_certificate.example](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_certificate) (resource)
- [azurerm_nat_gateway.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/nat_gateway) (resource)
- [azurerm_nat_gateway_public_ip_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/nat_gateway_public_ip_association) (resource)
- [azurerm_network_security_group.myNSG](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) (resource)
- [azurerm_public_ip.natgwpip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) (resource)
- [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_subnet.subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_subnet_nat_gateway_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_nat_gateway_association) (resource)
- [azurerm_virtual_network.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [time_sleep.wait_60_seconds](https://registry.terraform.io/providers/hashicorp/time/0.10.0/docs/resources/sleep) (resource)
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

### <a name="module_avm_res_keyvault_vault"></a> [avm\_res\_keyvault\_vault](#module\_avm\_res\_keyvault\_vault)

Source: Azure/avm-res-keyvault-vault/azurerm

Version: 0.3.0

### <a name="module_naming"></a> [naming](#module\_naming)

Source: Azure/naming/azurerm

Version: 0.3.0

### <a name="module_terraform-azurerm-avm-res-compute-virtualmachinescaleset"></a> [terraform-azurerm-avm-res-compute-virtualmachinescaleset](#module\_terraform-azurerm-avm-res-compute-virtualmachinescaleset)

Source: ../../

Version:

<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.
<!-- END_TF_DOCS -->