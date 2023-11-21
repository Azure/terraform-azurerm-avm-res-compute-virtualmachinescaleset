terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.7.0, < 4.0.0"
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
  name     = module.naming.resource_group.name_unique
  location = "eastus"
  tags = {
    source = "AVM Sample Default Deployment"
  }
}

resource "azurerm_virtual_network" "this" {
  name                = module.naming.virtual_network.name_unique
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.0.0.0/16"]
  dns_servers         = ["10.0.0.4", "10.0.0.5"]
  tags = {
    source = "AVM Sample Default Deployment"
  }
}

resource "azurerm_subnet" "subnet" {
  name                 = "VMSS-Subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "natgwpip" {
  name                = module.naming.public_ip.name_unique
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags = {
    source = "AVM Sample Default Deployment"
  }
}

resource "azurerm_nat_gateway" "this" {
  name                = "MyNatGateway"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags = {
    source = "AVM Sample Default Deployment"
  }
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  public_ip_address_id = azurerm_public_ip.natgwpip.id
  nat_gateway_id       = azurerm_nat_gateway.this.id
}

resource "azurerm_subnet_nat_gateway_association" "this" {
  subnet_id      = azurerm_subnet.subnet.id
  nat_gateway_id = azurerm_nat_gateway.this.id
}

resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# This is the module call
module "terraform-azurerm-avm-res-compute-virtualmachinescaleset" {
  source = "../../"
  # source             = "Azure/avm-res-compute-virtualmachinescaleset/azurerm"
  name                = module.naming.virtual_machine_scale_set.name_unique
  resource_group_name = azurerm_resource_group.this.name
  enable_telemetry    = var.enable_telemetry
  location            = azurerm_resource_group.this.location
  network_interface = [{
    name = "VMSS-NIC"
    ip_configuration = [{
      name                          = "VMSS-IPConfig"
      subnet_id                     = azurerm_subnet.subnet.id
    }]
  }] 
  os_profile = {
    linux_configuration = {
      disable_password_authentication = false
      user_data_base64                = base64encode(file("user-data.sh"))
      admin_username                  = "azureuser"
      admin_password                  = "P@ssw0rd1234!"
      admin_ssh_key = toset([{
        username   = "azureuser"
        public_key = tls_private_key.example_ssh.public_key_openssh
        # Replace if you have a public key file
        #public_key = file("<filename>")
      }])
    }
  }
  source_image_reference = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-LTS-gen2"
    version   = "latest"
  }
  tags = {
    source = "AVM Sample Default Deployment"
  }
  # Uncomment the code below to implement a VMSS Lock
  #lock = {
  #  name = "VMSSNoDelete"
  #  kind = "CanNotDelete"
  #}
  depends_on = [azurerm_subnet_nat_gateway_association.this]
}

output "location" {
  value = azurerm_resource_group.this.location
}

output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "virtual_machine_scale_set_id" {
  value = module.terraform-azurerm-avm-res-compute-virtualmachinescaleset.resource
}

output "virtual_machine_scale_set_unique_id" {
  value = module.terraform-azurerm-avm-res-compute-virtualmachinescaleset.unique_id
}