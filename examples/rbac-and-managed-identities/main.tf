terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.85, < 4.0"
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
    source = "AVM Sample RBAC and MI Deployment"
  }
}

resource "azurerm_virtual_network" "this" {
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.this.location
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.this.name
  dns_servers         = ["10.0.0.4", "10.0.0.5"]
  tags = {
    source = "AVM Sample RBAC and MI Deployment"
  }
}

resource "azurerm_subnet" "subnet" {
  address_prefixes     = ["10.0.1.0/24"]
  name                 = "VMSS-Subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
}

# network security group for the subnet with a rule to allow http, https and ssh traffic
resource "azurerm_network_security_group" "this" {
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
    source = "AVM Sample RBAC and MI Deployment"
  }
  zones = ["1", "2", "3"]
}

resource "azurerm_nat_gateway" "this" {
  location            = azurerm_resource_group.this.location
  name                = "MyNatGateway"
  resource_group_name = azurerm_resource_group.this.name
  tags = {
    source = "AVM Sample RBAC and MI Deployment"
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

resource "azurerm_user_assigned_identity" "example_identity" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.user_assigned_identity.name_unique
  resource_group_name = azurerm_resource_group.this.name
  tags = {
    source = "AVM Sample RBAC and MI Deployment"
  }
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
  platform_fault_domain_count = 1
  admin_password              = "P@ssw0rd1234!"
  sku_name                    = "Standard_D2s_v4"
  instances                   = 2
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
  role_assignments = {
    role_assignment = {
      principal_id               = data.azurerm_client_config.current.object_id
      role_definition_id_or_name = "Reader"
      description                = "Assign the Reader role to the deployment user on this virtual machine scale set resource scope."
    }
  }
  tags = {
    source = "AVM Sample RBAC and MI Deployment"
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
  value       = module.terraform_azurerm_avm_res_compute_virtualmachinescaleset.resource_id
  description = "The ID of the Virtual Machine Scale Set."
}

output "virtual_machine_scale_set_name" {
  value       = module.terraform_azurerm_avm_res_compute_virtualmachinescaleset.resource_name
  description = "The name of the Virtual Machine Scale Set."
}

output "virtual_machine_scale_set" {
  value       = module.terraform_azurerm_avm_res_compute_virtualmachinescaleset.resource
  sensitive   = true
  description = "All attributes of the Virtual Machine Scale Set resource."
}