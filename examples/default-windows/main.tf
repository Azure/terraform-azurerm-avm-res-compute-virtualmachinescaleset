resource "random_integer" "region_index" {
  max = length(module.regions.regions_by_name) - 1
  min = 0
}

resource "random_integer" "zone_index" {
  max = length(module.regions.regions_by_name[module.regions.regions[random_integer.region_index.result].name].zones)
  min = 1
}

module "get_valid_sku_for_deployment_region" {
  source = "../../modules/sku_selector"

  deployment_region = module.regions.regions[random_integer.region_index.result].name
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  location = module.regions.regions[random_integer.region_index.result].name
  name     = module.naming.resource_group.name_unique
  tags     = local.tags
}

resource "azurerm_virtual_network" "this" {
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.this.location
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_subnet" "subnet" {
  address_prefixes     = ["10.0.1.0/24"]
  name                 = module.naming.subnet.name_unique
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
}

# network security group for the nic with a rule to allow http traffic
resource "azurerm_network_security_group" "nic" {
  location            = azurerm_resource_group.this.location
  name                = "${module.naming.network_security_group.name_unique}-nic"
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
}

# network security group for the subnet with a rule to allow http traffic
resource "azurerm_network_security_group" "subnet" {
  location            = azurerm_resource_group.this.location
  name                = "${module.naming.network_security_group.name_unique}-subnet"
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
}

resource "azurerm_subnet_network_security_group_association" "this" {
  network_security_group_id = azurerm_network_security_group.subnet.id
  subnet_id                 = azurerm_subnet.subnet.id
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
  zones               = ["1"]
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  nat_gateway_id       = azurerm_nat_gateway.this.id
  public_ip_address_id = azurerm_public_ip.natgwpip.id
}

resource "azurerm_subnet_nat_gateway_association" "this" {
  nat_gateway_id = azurerm_nat_gateway.this.id
  subnet_id      = azurerm_subnet.subnet.id
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
  sku_name                    = module.get_valid_sku_for_deployment_region.sku
  instances                   = 2
  extension_protected_setting = {}
  admin_ssh_keys              = []
  user_data_base64            = null
  boot_diagnostics = {
    storage_account_uri = "" # Enable boot diagnostics
  }
  network_interface = [{
    name = "VMSS-NIC"
    network_security_group_id = azurerm_network_security_group.nic.id
    ip_configuration = [{
      name      = "VMSS-IPConfig"
      subnet_id = azurerm_subnet.subnet.id
    }]
  }]
  os_profile = {
    custom_data = base64encode(file("init-script.ps1"))
    /*custom_data = <<-EOF
  <powershell>
    Install-WindowsFeature -name Web-Server -IncludeManagementTools
    New-Item -Path "C:\inetpub\wwwroot\index.html" -ItemType "file" -Value "<html><body><h1>Healthy</h1></body></html>"
  </powershell>
  EOF*/
    windows_configuration = {
      disable_password_authentication = false
      admin_username                  = "azureuser"
      license_type                    = "None"
      hotpatching_enabled             = false
      timezone                        = "Pacific Standard Time"
      provision_vm_agent              = true
      winrm_listener = [{
        protocol = "Http"
      }]
    }
  }
  data_disk = [{
    caching                   = "ReadWrite"
    create_option             = "Empty"
    disk_size_gb              = 10
    lun                       = 0
    managed_disk_type         = "StandardSSD_LRS"
    storage_account_type      = "StandardSSD_LRS"
    write_accelerator_enabled = false
  }]
  source_image_reference = {
    publisher = "MicrosoftWindowsServer" # 2022-datacenter-azure-edition
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
  extension = [
 {
    name                        = "CustomScriptExtension"
    publisher                   = "Microsoft.Compute"
    type                        = "CustomScriptExtension"
    type_handler_version        = "1.10"
    auto_upgrade_minor_version  = true
    failure_suppression_enabled = false    
    settings                    = "{\"commandToExecute\": \"powershell -ExecutionPolicy Unrestricted -File %SYSTEMDRIVE%/AzureData/CustomData.bin\"}"
  },
  {
    name                        = "HealthExtension"
    publisher                   = "Microsoft.ManagedServices"
    type                        = "ApplicationHealthWindows"
    type_handler_version        = "1.0"
    auto_upgrade_minor_version  = true
    failure_suppression_enabled = false
    settings                    = "{\"port\":80,\"protocol\":\"http\",\"requestPath\":\"index.html\"}"
  }]
  tags       = local.tags
  depends_on = [azurerm_subnet_nat_gateway_association.this]
}