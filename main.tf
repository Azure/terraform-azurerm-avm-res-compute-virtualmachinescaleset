resource "azurerm_orchestrated_virtual_machine_scale_set" "virtual_machine_scale_set" {
 # count = var.os_profile.linux_configuration != null && var.os_profile.windows_configuration == null ? 1 : 0  

  name                        = var.name
  tags                        = var.tags 
  resource_group_name         = var.resource_group_name
  location                    = var.location
  sku_name                    = var.sku_name
  instances                   = var.instances
  
  platform_fault_domain_count = 1               # For zonal deployments, this must be set to 1
  zones                       = var.zones # ["1", "2", "3"] # Zones required to lookup zone in the startup script

  os_profile {
    dynamic "linux_configuration" {
      for_each = var.os_profile.linux_configuration == null ? [] : ["linux_configuration"]
      content {      
        disable_password_authentication = var.os_profile.linux_configuration.disable_password_authentication
        admin_username                  = var.os_profile.linux_configuration.admin_username
        admin_password                  = var.os_profile.linux_configuration.admin_password
        #TODO: user_data_base64                = var.os_profile.linux_configuration.user_data_base64
        dynamic "admin_ssh_key" {
          for_each = var.os_profile.linux_configuration.admin_ssh_key == null ? [] : ["admin_ssh_key"]
          content {
            username                      = var.os_profile.linux_configuration.admin_ssh_key.username
            public_key                    = var.os_profile.linux_configuration.admin_ssh_key.public_key
          }
        }
        dynamic "secret" {
          for_each = var.os_profile.linux_configuration.secret == null ? [] : ["secret"]
          content {
            key_vault_id                  = var.os_profile.linux_configuration.secret.key_vault_id
            certificate { 
              url                         = var.os_profile.linux_configuration.secret.certificate.url
            }   
          }
        }
      }
    }
    dynamic "windows_configuration" {
      for_each = var.os_profile.windows_configuration == null ? [] : ["windows_configuration"]
      content {
        admin_username                  = var.os_profile.windows_configuration.admin_username
        admin_password                  = var.os_profile.windows_configuration.admin_password
        computer_name_prefix            = var.os_profile.windows_configuration.computer_name_prefix
        enable_automatic_updates        = var.os_profile.windows_configuration.enable_automatic_updates
        hotpatching_enabled             = var.os_profile.windows_configuration.hotpatching_enabled
        patch_assessment_mode           = var.os_profile.windows_configuration.patch_assessment_mode
        patch_mode                      = var.os_profile.windows_configuration.patch_mode
        provision_vm_agent              = var.os_profile.windows_configuration.provision_vm_agent
        dynamic "secret" {
          for_each = var.os_profile.windows_configuration.secret == null ? [] : ["secret"]
          content {
            key_vault_id                  = var.os_profile.windows_configuration.secret.key_vault_id
            certificate { 
              url                         = var.os_profile.windows_configuration.secret.certificate.url
              store                       = var.os_profile.windows_configuration.secret.certificate.store
            }
          }
        }
      }
    } 
  }

  source_image_reference {
    publisher = var.source_image_reference.publisher
    offer     = var.source_image_reference.offer
    sku       = var.source_image_reference.sku
    version   = var.source_image_reference.version
  }

  os_disk {
    storage_account_type = var.os_disk.storage_account_type
    caching              = var.os_disk.caching
  }

  network_interface {
    name                          = "nic"
    primary                       = true
    enable_accelerated_networking = false
    ip_configuration {
      name                                   = "ipconfig"
      primary                                = true
      subnet_id                              = var.subnet_id
      load_balancer_backend_address_pool_ids = var.load_balancer_backend_address_pool_ids
    }
  }

  boot_diagnostics {
    storage_account_uri = ""
  }

  # Ignore changes to the instances property, so that the VMSS is not recreated when the number of instances is changed
  lifecycle {
    ignore_changes = [
      instances
    ]
  }

  dynamic "identity" {
    for_each = var.managed_identities == null ? [] : ["identity"]
    content {
      # VMSS Flex only supports User Assigned Managed Identities
      type = "UserAssigned"  
      identity_ids = var.managed_identities.user_assigned_resource_ids
    }
  }
}

resource "azurerm_management_lock" "this" {
  count      = var.lock.kind != "None" ? 1 : 0
  name       = coalesce(var.lock.name, "lock-${var.name}")
  scope      = azurerm_orchestrated_virtual_machine_scale_set.virtual_machine_scale_set.id
  lock_level = var.lock.kind
}

resource "azurerm_role_assignment" "this" {
  for_each                               = var.role_assignments
  scope                                  = azurerm_orchestrated_virtual_machine_scale_set.virtual_machine_scale_set.id
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
  principal_id                           = each.value.principal_id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
}

