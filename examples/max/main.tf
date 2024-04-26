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

#create a keyvault for storing the credential with RBAC for the deployment user
module "avm_res_keyvault_vault" {
  source                 = "Azure/avm-res-keyvault-vault/azurerm"
  version                = "0.5.3"
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

  tags = local.tags
}

resource "time_sleep" "wait_60_seconds" {
  create_duration = "60s"

  depends_on = [module.avm_res_keyvault_vault]
}

resource "azurerm_key_vault_certificate" "example" {
  key_vault_id = module.avm_res_keyvault_vault.resource.id
  name         = "generated-cert"
  tags         = local.tags

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
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"]

      subject_alternative_names {
        dns_names = ["internal.contoso.com", "domain.hello.world"]
      }
    }
  }

  depends_on = [time_sleep.wait_60_seconds]
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
  #priority      = "Spot"
  #max_bid_price = 0.1
  #priority_mix = {
  #  low_priority_virtual_machine_scale_set_percentage = 100
  #  spot_virtual_machine_scale_set_percentage         = 0
  #}
  #termination_notification = {
  #  enabled = true
  #  timeout = "PT5M"
  #}
  #eviction_policy = "Deallocate"
  # Instance Placement
  zone_balance                 = false
  zones                        = ["2"] # Zone redundancy is preferred, changed for max test
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
      computer_name_prefix            = "prefix"
      provision_vm_agent              = true
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
