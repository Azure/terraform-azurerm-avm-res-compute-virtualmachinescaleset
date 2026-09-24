mock_provider "azapi" {
  mock_data "azapi_resource" {
    defaults = {
      exists = false
      output = null
    }
  }

  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachineScaleSets/vmssrt"
    }
  }
}
mock_provider "modtm" {}
mock_provider "random" {}

variables {
  location                    = "westeurope"
  name                        = "vmssrt"
  parent_id                   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  admin_password              = "AvmUnitTest123!"
  admin_password_version      = "1"
  automatic_instance_repair   = null
  custom_data                 = base64encode("rt-test")
  custom_data_version         = "1"
  extension_protected_setting = {}
  user_data_base64            = base64encode("rt-test")
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
  zones = ["1"]
}

# Replacement triggers must never be derived from data.azapi_resource.existing_vmss.
# A `depends_on` on the calling module block defers that read to apply, and any
# unknown member makes azapi's RequiresReplaceIfNotNull replace the scale set (#205, #227).
# The object shape must also stay fixed, or every existing scale set is replaced on upgrade.

run "trigger_shape_and_type_match_existing_state" {
  command = apply

  assert {
    condition = azapi_resource.virtual_machine_scale_set.replace_triggers_external_values == {
      zones_removal_trigger          = tostring(null)
      single_placement_group_trigger = tostring(null)
    }
    error_message = "replace_triggers_external_values must stay an object of two string-typed nulls to match existing state."
  }
}

run "zone_removal_does_not_auto_replace" {
  command = plan

  override_data {
    target          = data.azapi_resource.existing_vmss
    override_during = plan
    values = {
      exists = true
      output = {
        zones      = ["1", "2"]
        properties = { singlePlacementGroup = false }
      }
    }
  }

  assert {
    condition     = azapi_resource.virtual_machine_scale_set.replace_triggers_external_values.zones_removal_trigger == null
    error_message = "Removing a zone must not be turned into an automatic replacement; the Compute API rejects it and the caller recreates with -replace."
  }
}

run "single_placement_group_false_to_true_does_not_auto_replace" {
  command = plan

  variables {
    single_placement_group = true
  }

  override_data {
    target          = data.azapi_resource.existing_vmss
    override_during = plan
    values = {
      exists = true
      output = {
        zones      = ["1"]
        properties = { singlePlacementGroup = false }
      }
    }
  }

  assert {
    condition     = azapi_resource.virtual_machine_scale_set.replace_triggers_external_values.single_placement_group_trigger == null
    error_message = "Flipping single_placement_group from false to true must not be turned into an automatic replacement."
  }
}
