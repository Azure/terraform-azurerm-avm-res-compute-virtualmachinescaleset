# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.1"
}

module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "0.3.0"

  availability_zones_filter = true
}

resource "random_integer" "region_index" {
  max = length(module.regions.regions_by_name) - 1
  min = 0
}

# Hibernation is only offered on a subset of VM sizes, so the selector is constrained to sizes that
# report the `HibernationSupported` capability. Without this the scale set deploys but Azure refuses
# to enable hibernation on it.
module "get_valid_sku_for_deployment_region" {
  source = "../../modules/sku_selector"

  deployment_region     = module.regions.regions[random_integer.region_index.result].name
  hibernation_supported = true
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  location = module.regions.regions[random_integer.region_index.result].name
  name     = module.naming.resource_group.name_unique
  tags     = local.tags
}

resource "azurerm_virtual_network" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.0.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "subnet" {
  name                 = module.naming.subnet.name_unique
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.1.0/24"]
}

# The instances only need outbound access, so the group keeps its default rules and adds none.
resource "azurerm_network_security_group" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.network_security_group.name_unique
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_subnet_network_security_group_association" "this" {
  network_security_group_id = azurerm_network_security_group.this.id
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

# The hibernate extension is downloaded from the internet, so the instances need outbound access.
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

resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# This is the module call
module "terraform_azurerm_avm_res_compute_virtualmachinescaleset" {
  source = "../../"

  extension_protected_setting = {}
  location                    = azurerm_resource_group.this.location
  name                        = module.naming.virtual_machine_scale_set.name_unique
  parent_id                   = azurerm_resource_group.this.id
  user_data_base64            = null
  # Hibernation can only be requested when the scale set is created. Toggling it later forces
  # replacement, because the Azure API will not accept the change in place.
  additional_capabilities = {
    hibernation_enabled = true
  }
  admin_ssh_keys = [(
    {
      id         = tls_private_key.example_ssh.id
      public_key = tls_private_key.example_ssh.public_key_openssh
      username   = "azureuser"
    }
  )]
  enable_telemetry = var.enable_telemetry
  # `LinuxHibernateExtension` configures the guest OS to suspend to disk. Enabling the capability on
  # the scale set only makes hibernation available - without this the instances still cannot be
  # hibernated.
  #
  # The health extension is required because the module enables `automatic_instance_repair` by
  # default. It probes SSH over TCP rather than an application port, because this example runs no
  # workload for an HTTP probe to reach.
  extension = [
    {
      name                               = "LinuxHibernateExtension"
      publisher                          = "Microsoft.CPlat.Core"
      type                               = "LinuxHibernateExtension"
      type_handler_version               = "1.0"
      auto_upgrade_minor_version_enabled = true
    },
    {
      name                               = "HealthExtension"
      publisher                          = "Microsoft.ManagedServices"
      type                               = "ApplicationHealthLinux"
      type_handler_version               = "1.0"
      auto_upgrade_minor_version_enabled = true
      failure_suppression_enabled        = false
      settings                           = "{\"protocol\":\"tcp\",\"port\":22}"
    }
  ]
  instances = 1
  network_interface = [{
    name                      = "VMSS-NIC"
    network_security_group_id = azurerm_network_security_group.this.id
    primary                   = true
    ip_configuration = [{
      name      = "VMSS-IPConfig"
      primary   = true
      subnet_id = azurerm_subnet.subnet.id
    }]
  }]
  # Hibernation writes the contents of RAM to the OS disk, so it needs a persistent disk with room
  # for the memory image. An ephemeral OS disk (`diff_disk_settings`) is rejected by the module.
  os_disk = {
    caching              = "ReadWrite"
    disk_size_gb         = 64
    storage_account_type = "Premium_LRS"
  }
  os_profile = {
    linux_configuration = {
      admin_username                  = "azureuser"
      admin_ssh_key_id                = toset([tls_private_key.example_ssh.id])
      disable_password_authentication = true
    }
  }
  sku_name = module.get_valid_sku_for_deployment_region.sku
  # Ubuntu 22.04 LTS is one of the distros that supports hibernation.
  source_image_reference = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-LTS-gen2"
    version   = "latest"
  }
  tags = local.tags

  depends_on = [azurerm_subnet_nat_gateway_association.this]
}

# Read the scale set back to prove Azure actually persisted the capability. A successful PUT is not
# evidence on its own - Azure silently drops body properties it does not accept, so asserting on the
# response is the only way to catch that regression.
data "azapi_resource" "hibernation_readback" {
  name                   = module.terraform_azurerm_avm_res_compute_virtualmachinescaleset.resource_name
  parent_id              = azurerm_resource_group.this.id
  type                   = "Microsoft.Compute/virtualMachineScaleSets@2025-04-01"
  response_export_values = ["properties.additionalCapabilities"]

  lifecycle {
    postcondition {
      condition     = try(self.output.properties.additionalCapabilities.hibernationEnabled, false) == true
      error_message = "Azure did not report `properties.additionalCapabilities.hibernationEnabled` as `true` on the deployed scale set, so hibernation is not enabled despite the deployment succeeding."
    }
  }
  depends_on = [module.terraform_azurerm_avm_res_compute_virtualmachinescaleset]
}
