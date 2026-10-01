mock_provider "azapi" {
  mock_data "azapi_resource" {
    defaults = {
      exists = false
      output = null
    }
  }

  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachineScaleSets/vmsscmc"
    }
  }
}
mock_provider "modtm" {}
mock_provider "random" {}

variables {
  location                    = "qatarcentral"
  name                        = "vmsscmc"
  parent_id                   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  admin_password              = "AvmUnitTest123!"
  admin_password_version      = "1"
  automatic_instance_repair   = null
  custom_data                 = base64encode("cmc-test")
  custom_data_version         = "1"
  encryption_at_host_enabled  = true
  extension_protected_setting = {}
  user_data_base64            = base64encode("cmc-test")
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

# Azure rejects the request with "InvalidParameter: Parameter
# 'constrainedMaximumCapacity' is not allowed" unless the property is true or omitted.
run "omitted_when_the_scale_set_does_not_exist" {
  command = apply

  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.constrainedMaximumCapacity == null
    error_message = "'constrainedMaximumCapacity' must resolve to null on create so it is dropped from the Compute API request."
  }
}

run "omitted_when_the_existing_scale_set_reports_false" {
  command = apply

  override_data {
    target = data.azapi_resource.existing_vmss
    values = {
      exists = true
      output = {
        properties = {
          constrainedMaximumCapacity = false
        }
      }
    }
  }

  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.constrainedMaximumCapacity == null
    error_message = "A false 'constrainedMaximumCapacity' read from the deployed scale set must not be echoed back to the Compute API."
  }
}

run "omitted_when_the_existing_scale_set_does_not_report_the_property" {
  command = apply

  override_data {
    target = data.azapi_resource.existing_vmss
    values = {
      exists = true
      output = {
        properties = {
          singlePlacementGroup = false
        }
      }
    }
  }

  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.constrainedMaximumCapacity == null
    error_message = "An absent 'constrainedMaximumCapacity' in the read response must resolve to null rather than fail."
  }
}

run "preserved_when_the_existing_scale_set_reports_true" {
  command = apply

  override_data {
    target = data.azapi_resource.existing_vmss
    values = {
      exists = true
      output = {
        properties = {
          constrainedMaximumCapacity = true
        }
      }
    }
  }

  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.constrainedMaximumCapacity == true
    error_message = "A true 'constrainedMaximumCapacity' must be preserved so an out-of-band opt-in is not reset."
  }
}
