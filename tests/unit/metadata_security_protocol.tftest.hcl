mock_provider "azapi" {
  mock_data "azapi_resource" {
    defaults = {
      exists = false
      output = null
    }
  }

  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachineScaleSets/vmss-msp"
    }
  }
}
mock_provider "modtm" {}
mock_provider "random" {}

variables {
  extension_protected_setting = {}
  location                    = "eastus"
  name                        = "vmss-msp"
  parent_id                   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  automatic_instance_repair   = null
  admin_password              = "AvmUnitTest123!"
  admin_password_version      = "1"
  custom_data                 = base64encode("msp-test")
  custom_data_version         = "1"
  encryption_at_host_enabled  = true
  user_data_base64            = base64encode("msp-test")
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
  proxy_agent_settings = {
    enabled            = true
    key_incarnation_id = 2
    imds = {
      mode = "Audit"
    }
    wire_server = {
      mode = "Enforce"
    }
  }
}

run "windows_inline_proxy_agent_settings" {
  command = apply

  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.securityProfile.proxyAgentSettings.enabled
    error_message = "MSP must be enabled in the VMSS security profile."
  }
  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.securityProfile.encryptionAtHost
    error_message = "Adding MSP must preserve encryption-at-host settings in the shared security profile."
  }
  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.securityProfile.proxyAgentSettings.keyIncarnationId == 2
    error_message = "The proxy agent key incarnation ID must be mapped to the Compute API field."
  }
  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.securityProfile.proxyAgentSettings.imds.mode == "Audit"
    error_message = "The IMDS inline mode must be mapped to proxyAgentSettings."
  }
  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.securityProfile.proxyAgentSettings.wireServer.mode == "Enforce"
    error_message = "The WireServer inline mode must be mapped to proxyAgentSettings."
  }
  assert {
    condition     = !can(azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.securityProfile.proxyAgentSettings.addProxyAgentExtension)
    error_message = "The Linux-only addProxyAgentExtension property must not be sent for Windows."
  }
}

run "linux_enables_proxy_agent_extension_by_default" {
  command = apply

  variables {
    os_profile = {
      linux_configuration = {
        admin_username = "azureuser"
        patch_mode     = "ImageDefault"
      }
    }
    source_image_reference = {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-jammy"
      sku       = "22_04-lts-gen2"
      version   = "latest"
    }
    proxy_agent_settings = {
      enabled = true
      imds = {
        mode = "Audit"
      }
      wire_server = {
        mode = "Audit"
      }
    }
  }

  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.securityProfile.proxyAgentSettings.addProxyAgentExtension
    error_message = "Linux MSP must install the Proxy Agent extension by default when MSP is enabled."
  }
}

run "linux_extension_defaults_true_when_msp_is_disabled" {
  command = apply

  variables {
    os_profile = {
      linux_configuration = {
        admin_username = "azureuser"
        patch_mode     = "ImageDefault"
      }
    }
    source_image_reference = {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-jammy"
      sku       = "22_04-lts-gen2"
      version   = "latest"
    }
    proxy_agent_settings = {
      enabled = false
    }
  }

  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.securityProfile.proxyAgentSettings.addProxyAgentExtension
    error_message = "Linux must install the Proxy Agent extension by default even when MSP starts disabled."
  }
}

run "linux_preserves_explicit_false_for_proxy_agent_extension" {
  command = apply

  variables {
    os_profile = {
      linux_configuration = {
        admin_username = "azureuser"
        patch_mode     = "ImageDefault"
      }
    }
    source_image_reference = {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-jammy"
      sku       = "22_04-lts-gen2"
      version   = "latest"
    }
    proxy_agent_settings = {
      enabled                   = true
      add_proxy_agent_extension = false
    }
  }

  assert {
    condition     = !azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.securityProfile.proxyAgentSettings.addProxyAgentExtension
    error_message = "An explicit false must prevent automatic Proxy Agent extension installation on Linux."
  }
}

run "windows_accepts_false_and_omits_linux_extension_property" {
  command = apply

  variables {
    proxy_agent_settings = {
      enabled                   = true
      add_proxy_agent_extension = false
    }
  }

  assert {
    condition     = !can(azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.securityProfile.proxyAgentSettings.addProxyAgentExtension)
    error_message = "Windows may explicitly disable implicit extension installation, but the Linux-only API property must be omitted."
  }
}

run "empty_endpoint_objects_are_omitted" {
  command = apply

  variables {
    proxy_agent_settings = {
      imds        = {}
      wire_server = {}
    }
  }

  assert {
    condition     = !can(azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.securityProfile.proxyAgentSettings.imds)
    error_message = "An empty IMDS object must be omitted from the Compute API request."
  }
  assert {
    condition     = !can(azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.securityProfile.proxyAgentSettings.wireServer)
    error_message = "An empty WireServer object must be omitted from the Compute API request."
  }
}

run "linked_access_control_profiles" {
  command = apply

  variables {
    proxy_agent_settings = {
      imds = {
        in_vm_access_control_profile_reference_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/galleries/gallery-test/inVMAccessControlProfiles/imds-profile/versions/1.0.0"
      }
      wire_server = {
        in_vm_access_control_profile_reference_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/galleries/gallery-test/inVMAccessControlProfiles/wireserver-profile/versions/1.0.0"
      }
    }
  }

  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.securityProfile.proxyAgentSettings.imds.inVMAccessControlProfileReferenceId == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/galleries/gallery-test/inVMAccessControlProfiles/imds-profile/versions/1.0.0"
    error_message = "The IMDS linked access-control profile ID must be mapped unchanged."
  }
  assert {
    condition     = azapi_resource.virtual_machine_scale_set.body.properties.virtualMachineProfile.securityProfile.proxyAgentSettings.wireServer.inVMAccessControlProfileReferenceId == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/galleries/gallery-test/inVMAccessControlProfiles/wireserver-profile/versions/1.0.0"
    error_message = "The WireServer linked access-control profile ID must be mapped unchanged."
  }
}

run "invalid_endpoint_mode_is_rejected" {
  command = plan

  variables {
    proxy_agent_settings = {
      imds = {
        mode = "Block"
      }
    }
  }

  expect_failures = [var.proxy_agent_settings]
}

run "inline_and_linked_endpoint_settings_are_mutually_exclusive" {
  command = plan

  variables {
    proxy_agent_settings = {
      imds = {
        mode                                      = "Audit"
        in_vm_access_control_profile_reference_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/galleries/gallery-test/inVMAccessControlProfiles/imds-profile/versions/1.0.0"
      }
    }
  }

  expect_failures = [var.proxy_agent_settings]
}

run "invalid_linked_profile_id_is_rejected" {
  command = plan

  variables {
    proxy_agent_settings = {
      wire_server = {
        in_vm_access_control_profile_reference_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/galleries/gallery-test/inVMAccessControlProfiles/wireserver-profile"
      }
    }
  }

  expect_failures = [var.proxy_agent_settings]
}

run "negative_key_incarnation_id_is_rejected" {
  command = plan

  variables {
    proxy_agent_settings = {
      key_incarnation_id = -1
    }
  }

  expect_failures = [var.proxy_agent_settings]
}

run "fractional_key_incarnation_id_is_rejected" {
  command = plan

  variables {
    proxy_agent_settings = {
      key_incarnation_id = 1.5
    }
  }

  expect_failures = [var.proxy_agent_settings]
}

run "linux_extension_setting_is_rejected_for_windows" {
  command = plan

  variables {
    proxy_agent_settings = {
      add_proxy_agent_extension = true
    }
  }

  expect_failures = [var.proxy_agent_settings]
}
