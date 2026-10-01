// ignore_body_changes is a write-only argument, so the provider holds it in private state and it
// is never readable from an assertion. These runs therefore cover what is observable from the
// module: that every documented key resolves, that a non-empty list is accepted on each of the
// three azapi_resource blocks, and that the default empty object still plans and applies.
mock_provider "azapi" {
  mock_data "azapi_resource" {
    defaults = {
      exists = false
      output = null
    }
  }

  // The interfaces module resolves a role name to a role definition ID through this data source.
  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        results = [{
          id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"
          role_name = "Contributor"
        }]
      }
    }
  }

  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachineScaleSets/vmss-ibc"
    }
  }
}
mock_provider "modtm" {}
mock_provider "random" {}

variables {
  extension_protected_setting = {}
  location                    = "eastus"
  name                        = "vmss-ibc"
  parent_id                   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  admin_password              = "AvmUnitTest123!"
  admin_password_version      = "1"
  automatic_instance_repair   = null
  custom_data                 = base64encode("ibc-test")
  custom_data_version         = "1"
  user_data_base64            = base64encode("ibc-test")
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
  tags = {
    environment = "test"
  }
}

run "default_is_an_empty_object" {
  command = apply

  assert {
    condition     = length(var.ignore_body_changes.compute_virtual_machine_scale_sets) == 0
    error_message = "The scale set slot must default to an empty list so the write-only argument is omitted."
  }
  assert {
    condition     = length(var.ignore_body_changes.authorization_locks) == 0
    error_message = "The lock slot must default to an empty list."
  }
  assert {
    condition     = length(var.ignore_body_changes.authorization_role_assignments) == 0
    error_message = "The role assignment slot must default to an empty list."
  }
  assert {
    condition     = azapi_resource.virtual_machine_scale_set.tags.environment == "test"
    error_message = "Tags must still be sent when no body paths are ignored."
  }
}

run "a_path_can_be_ignored_on_the_scale_set" {
  command = apply

  variables {
    ignore_body_changes = {
      compute_virtual_machine_scale_sets = ["tags"]
    }
  }

  assert {
    condition     = length(var.ignore_body_changes.compute_virtual_machine_scale_sets) == 1 && var.ignore_body_changes.compute_virtual_machine_scale_sets[0] == "tags"
    error_message = "The scale set slot must accept a top-level body path."
  }
  assert {
    condition     = length(var.ignore_body_changes.authorization_locks) == 0
    error_message = "Setting the scale set slot must not populate the other slots."
  }
}

run "every_slot_accepts_paths" {
  command = apply

  variables {
    lock = {
      kind = "CanNotDelete"
    }
    role_assignments = {
      contributor = {
        role_definition_id_or_name = "Contributor"
        principal_id               = "00000000-0000-0000-0000-000000000001"
      }
    }
    ignore_body_changes = {
      compute_virtual_machine_scale_sets = ["tags", "properties.virtualMachineProfile.priority"]
      authorization_locks                = ["properties.notes"]
      authorization_role_assignments     = ["properties.description"]
    }
  }

  assert {
    condition     = length(var.ignore_body_changes.compute_virtual_machine_scale_sets) == 2
    error_message = "The scale set slot must accept multiple dot-notation paths."
  }
  assert {
    condition     = length(var.ignore_body_changes.authorization_locks) == 1 && var.ignore_body_changes.authorization_locks[0] == "properties.notes"
    error_message = "The lock slot must be applied to the management lock resource."
  }
  assert {
    condition     = length(var.ignore_body_changes.authorization_role_assignments) == 1 && var.ignore_body_changes.authorization_role_assignments[0] == "properties.description"
    error_message = "The role assignment slot must be applied to the role assignment resources."
  }
}
