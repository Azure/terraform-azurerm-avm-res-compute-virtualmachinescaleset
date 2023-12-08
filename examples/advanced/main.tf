terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.83, < 4.0"
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
    source = "AVM Sample Default Deployment"
  }
}

resource "azurerm_virtual_network" "this" {
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.this.location
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.this.name
  dns_servers         = ["10.0.0.4", "10.0.0.5"]
  tags = {
    source = "AVM Sample Default Deployment"
  }
}

resource "azurerm_subnet" "subnet" {
  address_prefixes     = ["10.0.1.0/24"]
  name                 = "VMSS-Subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
}

resource "azurerm_public_ip" "natgwpip" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.this.location
  name                = module.naming.public_ip.name_unique
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
  tags = {
    source = "AVM Sample Default Deployment"
  }
  zones = ["1", "2", "3"]
}

resource "azurerm_nat_gateway" "this" {
  location            = azurerm_resource_group.this.location
  name                = "MyNatGateway"
  resource_group_name = azurerm_resource_group.this.name
  tags = {
    source = "AVM Sample Default Deployment"
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

resource "azurerm_storage_account" "this" {
  account_replication_type = "LRS"
  account_tier             = "Standard"
  location                 = azurerm_resource_group.this.location
  name                     = module.naming.storage_account.name_unique
  resource_group_name      = azurerm_resource_group.this.name
  tags = {
    source = "AVM Sample Default Deployment"
  }
}

resource "azurerm_proximity_placement_group" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.proximity_placement_group.name_unique
  resource_group_name = azurerm_resource_group.this.name
  tags = {
    source = "AVM Sample Default Deployment"
  }
}

# This is the module call
module "terraform-azurerm-avm-res-compute-virtualmachinescaleset" {
  source = "../../"
  # source             = "Azure/avm-res-compute-virtualmachinescaleset/azurerm"
  name                        = module.naming.virtual_machine_scale_set.name_unique
  resource_group_name         = azurerm_resource_group.this.name
  enable_telemetry            = var.enable_telemetry
  location                    = azurerm_resource_group.this.location
  admin_password              = "P@ssw0rd1234!"
  platform_fault_domain_count = 1
  admin_ssh_keys = [(
    { 
      id = tls_private_key.example_ssh.id
      public_key = tls_private_key.example_ssh.public_key_openssh
      username = "azureuser"
    }
  )]
  # Spot variables
  priority      = "Spot"
  max_bid_price = 0.01
  priority_mix = {
    low_priority_virtual_machine_scale_set_percentage = 100
    spot_virtual_machine_scale_set_percentage         = 0
  }
  termination_notification = {
    enabled = true
    timeout = "PT5M"
  }
  eviction_policy = "Deallocate"
  # Instance Placement
  zone_balance                 = false
  zones                        = ["1"]
  proximity_placement_group_id = azurerm_proximity_placement_group.this.id
  single_placement_group       = true
  # Miscellanous settings
  encryption_at_host_enabled = true
  automatic_instance_repair = {
    enabled = false
  }
  boot_diagnostics = {
    storage_uri = azurerm_storage_account.this.primary_blob_endpoint
  }
  data_disk = [{
    caching                   = "ReadWrite"
    create_option             = "Empty"
    disk_size_gb              = 10
    lun                       = 0
    managed_disk_type         = "Standard_LRS"
    storage_account_type      = "Standard_LRS"
    write_accelerator_enabled = true
  }]
  # Network interface
  network_interface = [{
    name = "VMSS-NIC"
    ip_configuration = [{
      name      = "VMSS-IPConfig"
      subnet_id = azurerm_subnet.subnet.id
    }]
  }]
  # Extensions
  extension = [{
    name                       = "Custom Script Extension"
    publisher                  = "Microsoft.Azure.Extensions"
    type                       = "CustomScript"
    type_handler_version       = "2.0"
    auto_upgrade_minor_version = true
    settings                   = <<SETTINGS
      {
        "commandToExecute": "echo 'Hello World!' > /tmp/hello.txt"
      }
      SETTINGS
  }]
  # Extension protected settings
  extension_protected_setting = {
    "Custom Script Extension" = <<SETTINGS
      {
        "commandToExecute": "echo 'Protected Hello World!' > /tmp/protectedhello.txt"
      }
      SETTINGS
  }
  os_profile = {
    linux_configuration = {
      disable_password_authentication = false
      user_data_base64                = base64encode(file("user-data.sh"))
      admin_username                  = "azureuser"
      computer_name_prefix            = "prefix"
      provision_vm_agent              = true
      admin_ssh_key                   = toset([tls_private_key.example_ssh.id])
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
