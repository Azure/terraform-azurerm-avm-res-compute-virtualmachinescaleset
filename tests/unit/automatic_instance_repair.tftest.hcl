mock_provider "azapi" {
  mock_data "azapi_resource" {
    defaults = {
      exists = false
      output = null
    }
  }

  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachineScaleSets/vmssrpr"
    }
  }
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "random" {}

variables {
  location                   = "eastus"
  name                       = "vmssrpr"
  parent_id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  admin_password             = "AvmUnitTest123!"
  admin_password_version     = "1"
  custom_data                = base64encode("repair-test")
  custom_data_version        = "1"
  encryption_at_host_enabled = true
  extension = [{
    name                 = "HealthExtension"
    publisher            = "Microsoft.ManagedServices"
    type                 = "ApplicationHealthWindows"
    type_handler_version = "1.0"
    settings             = "{\"port\":80,\"protocol\":\"http\",\"requestPath\":\"/\"}"
  }]
  extension_protected_setting = {}
  user_data_base64            = base64encode("repair-test")
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

run "repair_action_is_omitted_by_default" {
  command = apply

  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.automaticRepairsPolicy.enabled == true
    error_message = "Automatic repairs must remain enabled by default."
  }
  assert {
    condition     = try(azapi_resource.virtual_machine_scale_set.body.properties.automaticRepairsPolicy.repairAction, null) == null
    error_message = "'repairAction' must be omitted so the API default applies."
  }
}

run "repair_action_is_sent_when_set" {
  command = apply

  variables {
    automatic_instance_repair = {
      enabled       = true
      repair_action = "Restart"
    }
  }

  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.automaticRepairsPolicy.repairAction == "Restart"
    error_message = "'repairAction' must be sent when 'repair_action' is set."
  }
}

run "invalid_repair_action_is_rejected" {
  command = plan

  variables {
    automatic_instance_repair = {
      enabled       = true
      repair_action = "Delete"
    }
  }

  expect_failures = [var.automatic_instance_repair]
}
