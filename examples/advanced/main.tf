# This is required for resource modules
resource "azurerm_resource_group" "this" {
  location = "westus2"
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
  tags = {
    source = "AVM Sample Default Deployment"
  }
  zones = ["1", "2", "3"]
}

resource "azurerm_nat_gateway" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.nat_gateway.name_unique
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
module "terraform_azurerm_avm_res_compute_virtualmachinescaleset" {
  source = "../../"
  # source             = "Azure/avm-res-compute-virtualmachinescaleset/azurerm"
  name                        = module.naming.virtual_machine_scale_set.name_unique
  resource_group_name         = azurerm_resource_group.this.name
  enable_telemetry            = var.enable_telemetry
  location                    = azurerm_resource_group.this.location
  admin_password              = "P@ssw0rd1234!"
  sku_name                    = "Standard_D2s_v4"
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
  # Spot variables
  priority      = "Spot"
  max_bid_price = 0.1
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
  single_placement_group       = false
  # Miscellanous settings
  encryption_at_host_enabled = false
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
    write_accelerator_enabled = false
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
    name                       = "CustomScriptExtension"
    publisher                  = "Microsoft.Azure.Extensions"
    type                       = "CustomScript"
    type_handler_version       = "2.0"
    auto_upgrade_minor_version = true
    settings                   = <<SETTINGS
      {
        "commandToExecute": "echo 'Hello World!' > /tmp/hello.txt"
      }
      SETTINGS
    },
    {
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

