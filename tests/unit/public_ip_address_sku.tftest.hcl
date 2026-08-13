mock_provider "azapi" {
  mock_data "azapi_resource" {
    defaults = {
      exists = false
      output = null
    }
  }

  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachineScaleSets/vmsspip"
    }
  }
}
mock_provider "modtm" {}
mock_provider "random" {}

variables {
  location                    = "eastus"
  name                        = "vmsspip"
  parent_id                   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  admin_password              = "AvmUnitTest123!"
  admin_password_version      = "1"
  automatic_instance_repair   = null
  custom_data                 = base64encode("pip-test")
  custom_data_version         = "1"
  encryption_at_host_enabled  = true
  extension_protected_setting = {}
  user_data_base64            = base64encode("pip-test")
  user_data_base64_version    = "1"
  network_interface = [{
    name    = "nic"
    primary = true
    ip_configuration = [{
      name      = "ipconfig"
      primary   = true
      subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-test"
    }]
  }]
  os_profile = {
    windows_configuration = {
      admin_username = "azureuser"
      patch_mode     = "AutomaticByOS"
    }
  }
  sku_name = "Standard_D2s_v5"
  source_image_reference = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }
}

# `public_ip_address` is a set, so indexing it made the whole block unusable.
run "public_ip_address_block_is_usable" {
  command = apply

  variables {
    network_interface = [{
      name    = "nic"
      primary = true
      ip_configuration = [{
        name      = "ipconfig"
        primary   = true
        subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-test"
        public_ip_address = [{
          name = "pip"
        }]
      }]
    }]
  }

  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.networkProfile.networkInterfaceConfigurations[0].properties.ipConfigurations[0].properties.publicIPAddressConfiguration.name == "pip"
    error_message = "The public IP address configuration name must be mapped to the Compute API request."
  }
  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.networkProfile.networkInterfaceConfigurations[0].properties.ipConfigurations[0].properties.publicIPAddressConfiguration.sku == null
    error_message = "The 'sku' block must not be sent when neither 'sku_name' nor 'sku_tier' is configured."
  }
}

run "standard_v2_sku_name_and_tier_are_mapped" {
  command = apply

  variables {
    network_api_version = "2023-06-01"
    network_interface = [{
      name    = "nic"
      primary = true
      ip_configuration = [{
        name      = "ipconfig"
        primary   = true
        subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-test"
        public_ip_address = [{
          name     = "pip"
          sku_name = "StandardV2"
          sku_tier = "Regional"
        }]
      }]
    }]
  }

  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.networkProfile.networkInterfaceConfigurations[0].properties.ipConfigurations[0].properties.publicIPAddressConfiguration.sku.name == "StandardV2"
    error_message = "The public IP 'sku_name' must be mapped unchanged to the Compute API 'sku.name' field."
  }
  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.networkProfile.networkInterfaceConfigurations[0].properties.ipConfigurations[0].properties.publicIPAddressConfiguration.sku.tier == "Regional"
    error_message = "The public IP 'sku_tier' must be mapped to the Compute API 'sku.tier' field."
  }
  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.networkProfile.networkApiVersion == "2023-06-01"
    error_message = "The configured 'network_api_version' must be sent as 'networkApiVersion'."
  }
}

run "tier_is_omitted_when_only_sku_name_is_set" {
  command = apply

  variables {
    network_interface = [{
      name    = "nic"
      primary = true
      ip_configuration = [{
        name      = "ipconfig"
        primary   = true
        subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-test"
        public_ip_address = [{
          name     = "pip"
          sku_name = "Standard"
        }]
      }]
    }]
  }

  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.networkProfile.networkInterfaceConfigurations[0].properties.ipConfigurations[0].properties.publicIPAddressConfiguration.sku.name == "Standard"
    error_message = "The public IP 'sku_name' must still be mapped when 'sku_tier' is omitted."
  }
  assert {
    condition     = !can(azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.networkProfile.networkInterfaceConfigurations[0].properties.ipConfigurations[0].properties.publicIPAddressConfiguration.sku.tier)
    error_message = "A null 'sku_tier' must be omitted from the Compute API request rather than sent explicitly."
  }
}

run "name_is_omitted_when_only_sku_tier_is_set" {
  command = apply

  variables {
    network_interface = [{
      name    = "nic"
      primary = true
      ip_configuration = [{
        name      = "ipconfig"
        primary   = true
        subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-test"
        public_ip_address = [{
          name     = "pip"
          sku_tier = "Global"
        }]
      }]
    }]
  }

  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.networkProfile.networkInterfaceConfigurations[0].properties.ipConfigurations[0].properties.publicIPAddressConfiguration.sku.tier == "Global"
    error_message = "The public IP 'sku_tier' must be mapped when 'sku_name' is omitted."
  }
  assert {
    condition     = !can(azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.networkProfile.networkInterfaceConfigurations[0].properties.ipConfigurations[0].properties.publicIPAddressConfiguration.sku.name)
    error_message = "A null 'sku_name' must be omitted from the Compute API request rather than sent explicitly."
  }
}

run "network_api_version_default_is_preserved" {
  command = apply

  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.networkProfile.networkApiVersion == "2020-11-01"
    error_message = "The default 'network_api_version' must continue to be sent unchanged."
  }
}

run "newer_network_api_version_is_accepted" {
  command = apply

  variables {
    network_api_version = "2024-05-01"
  }

  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.networkProfile.networkApiVersion == "2024-05-01"
    error_message = "An API version newer than the previously hard-coded allow list must be accepted."
  }
}

run "preview_network_api_version_is_accepted" {
  command = apply

  variables {
    network_api_version = "2024-05-01-preview"
  }

  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.networkProfile.networkApiVersion == "2024-05-01-preview"
    error_message = "A '-preview' suffixed API version must be accepted."
  }
}

run "malformed_network_api_version_is_rejected" {
  command = plan

  variables {
    network_api_version = "2023-6-1"
  }

  expect_failures = [var.network_api_version]
}

run "non_date_network_api_version_is_rejected" {
  command = plan

  variables {
    network_api_version = "latest"
  }

  expect_failures = [var.network_api_version]
}

run "legacy_combined_sku_name_is_rejected" {
  command = plan

  variables {
    network_interface = [{
      name    = "nic"
      primary = true
      ip_configuration = [{
        name      = "ipconfig"
        primary   = true
        subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-test"
        public_ip_address = [{
          name     = "pip"
          sku_name = "Standard_Regional"
        }]
      }]
    }]
  }

  expect_failures = [var.network_interface]
}

run "invalid_sku_tier_is_rejected" {
  command = plan

  variables {
    network_interface = [{
      name    = "nic"
      primary = true
      ip_configuration = [{
        name      = "ipconfig"
        primary   = true
        subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-test"
        public_ip_address = [{
          name     = "pip"
          sku_name = "Standard"
          sku_tier = "regional"
        }]
      }]
    }]
  }

  expect_failures = [var.network_interface]
}

run "standard_v2_with_unsupported_api_version_is_rejected" {
  command = plan

  variables {
    network_api_version = "2022-11-01"
    network_interface = [{
      name    = "nic"
      primary = true
      ip_configuration = [{
        name      = "ipconfig"
        primary   = true
        subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-test"
        public_ip_address = [{
          name     = "pip"
          sku_name = "StandardV2"
        }]
      }]
    }]
  }

  expect_failures = [var.network_interface]
}

run "standard_v2_is_accepted_on_the_minimum_api_version" {
  command = apply

  variables {
    network_api_version = "2023-06-01"
    network_interface = [{
      name    = "nic"
      primary = true
      ip_configuration = [{
        name      = "ipconfig"
        primary   = true
        subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-test"
        public_ip_address = [{
          name     = "pip"
          sku_name = "StandardV2"
        }]
      }]
    }]
  }

  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.networkProfile.networkInterfaceConfigurations[0].properties.ipConfigurations[0].properties.publicIPAddressConfiguration.sku.name == "StandardV2"
    error_message = "'StandardV2' must be accepted on the minimum supported API version."
  }
}

run "domain_name_label_and_idle_timeout_are_mapped" {
  command = apply

  variables {
    network_interface = [{
      name    = "nic"
      primary = true
      ip_configuration = [{
        name      = "ipconfig"
        primary   = true
        subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-test"
        public_ip_address = [{
          name                    = "pip"
          domain_name_label       = "avm-unit-test"
          idle_timeout_in_minutes = 10
          sku_name                = "Standard"
          sku_tier                = "Regional"
        }]
      }]
    }]
  }

  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.networkProfile.networkInterfaceConfigurations[0].properties.ipConfigurations[0].properties.publicIPAddressConfiguration.properties.dnsSettings.domainNameLabel == "avm-unit-test"
    error_message = "The 'domain_name_label' must be mapped to the Compute API 'dnsSettings.domainNameLabel' field."
  }
  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.networkProfile.networkInterfaceConfigurations[0].properties.ipConfigurations[0].properties.publicIPAddressConfiguration.properties.idleTimeoutInMinutes == 10
    error_message = "The 'idle_timeout_in_minutes' must be mapped to the Compute API 'idleTimeoutInMinutes' field."
  }
}

run "out_of_range_idle_timeout_is_rejected" {
  command = plan

  variables {
    network_interface = [{
      name    = "nic"
      primary = true
      ip_configuration = [{
        name      = "ipconfig"
        primary   = true
        subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-test"
        public_ip_address = [{
          name                    = "pip"
          idle_timeout_in_minutes = 33
        }]
      }]
    }]
  }

  expect_failures = [var.network_interface]
}
