resource "azurerm_orchestrated_virtual_machine_scale_set" "virtual_machine_scale_set" {
  location                      = var.location
  name                          = var.name
  platform_fault_domain_count   = var.platform_fault_domain_count
  resource_group_name           = var.resource_group_name
  capacity_reservation_group_id = var.capacity_reservation_group_id
  encryption_at_host_enabled    = var.encryption_at_host_enabled
  eviction_policy               = var.eviction_policy
  extension_operations_enabled  = var.extension_operations_enabled
  extensions_time_budget        = var.extensions_time_budget
  instances                     = var.instances
  license_type                  = var.license_type
  max_bid_price                 = var.max_bid_price
  priority                      = var.priority
  proximity_placement_group_id  = var.proximity_placement_group_id
  single_placement_group        = var.single_placement_group
  sku_name                      = var.sku_name
  source_image_id               = var.source_image_id
  tags                          = var.tags
  user_data_base64              = var.user_data_base64
  zone_balance                  = var.zone_balance
  zones                         = var.zones

  dynamic "additional_capabilities" {
    for_each = var.additional_capabilities == null ? [] : [var.additional_capabilities]

    content {
      ultra_ssd_enabled = additional_capabilities.value.ultra_ssd_enabled
    }
  }
  dynamic "automatic_instance_repair" {
    for_each = var.automatic_instance_repair == null ? [] : [var.automatic_instance_repair]

    content {
      enabled      = automatic_instance_repair.value.enabled
      grace_period = automatic_instance_repair.value.grace_period
    }
  }
  dynamic "boot_diagnostics" {
    for_each = var.boot_diagnostics == null ? [] : [var.boot_diagnostics]

    content {
      storage_account_uri = boot_diagnostics.value.storage_account_uri
    }
  }
  dynamic "data_disk" {
    for_each = var.data_disk == null ? [] : var.data_disk

    content {
      caching                        = data_disk.value.caching
      storage_account_type           = data_disk.value.storage_account_type
      create_option                  = data_disk.value.create_option
      disk_encryption_set_id         = data_disk.value.disk_encryption_set_id
      disk_size_gb                   = data_disk.value.disk_size_gb
      ultra_ssd_disk_iops_read_write = data_disk.value.ultra_ssd_disk_iops_read_write
      ultra_ssd_disk_mbps_read_write = data_disk.value.ultra_ssd_disk_mbps_read_write
      write_accelerator_enabled      = data_disk.value.write_accelerator_enabled
    }
  }
  dynamic "extension" {
    for_each = var.extension == null ? [] : var.extension

    content {
      name                                      = extension.value.name
      publisher                                 = extension.value.publisher
      type                                      = extension.value.type
      type_handler_version                      = extension.value.type_handler_version
      auto_upgrade_minor_version_enabled        = extension.value.auto_upgrade_minor_version_enabled
      extensions_to_provision_after_vm_creation = extension.value.extensions_to_provision_after_vm_creation
      failure_suppression_enabled               = extension.value.failure_suppression_enabled
      force_extension_execution_on_change       = extension.value.force_extension_execution_on_change
      protected_settings                        = lookup(var.extension_protected_setting, extension.value.name, "")
      settings                                  = extension.value.settings

      dynamic "protected_settings_from_key_vault" {
        for_each = extension.value.protected_settings_from_key_vault == null ? [] : [extension.value.protected_settings_from_key_vault]

        content {
          secret_url      = protected_settings_from_key_vault.value.secret_url
          source_vault_id = protected_settings_from_key_vault.value.source_vault_id
        }
      }
    }
  }
  dynamic "identity" {
    for_each = local.managed_identities.user_assigned

    content {
      identity_ids = identity.value.user_assigned_resource_ids
      type         = identity.value.type
    }
  }
  dynamic "network_interface" {
    for_each = var.network_interface == null ? [] : var.network_interface

    content {
      name                          = network_interface.value.name
      dns_servers                   = network_interface.value.dns_servers
      enable_accelerated_networking = network_interface.value.enable_accelerated_networking
      enable_ip_forwarding          = network_interface.value.enable_ip_forwarding
      network_security_group_id     = network_interface.value.network_security_group_id
      primary                       = network_interface.value.primary

      dynamic "ip_configuration" {
        for_each = network_interface.value.ip_configuration

        content {
          name                                         = ip_configuration.value.name
          application_gateway_backend_address_pool_ids = ip_configuration.value.application_gateway_backend_address_pool_ids
          application_security_group_ids               = ip_configuration.value.application_security_group_ids
          load_balancer_backend_address_pool_ids       = ip_configuration.value.load_balancer_backend_address_pool_ids
          primary                                      = ip_configuration.value.primary
          subnet_id                                    = ip_configuration.value.subnet_id
          version                                      = ip_configuration.value.version

          dynamic "public_ip_address" {
            for_each = ip_configuration.value.public_ip_address == null ? [] : ip_configuration.value.public_ip_address

            content {
              name                    = public_ip_address.value.name
              domain_name_label       = public_ip_address.value.domain_name_label
              idle_timeout_in_minutes = public_ip_address.value.idle_timeout_in_minutes
              public_ip_prefix_id     = public_ip_address.value.public_ip_prefix_id
              sku_name                = public_ip_address.value.sku_name
              version                 = public_ip_address.value.version

              dynamic "ip_tag" {
                for_each = public_ip_address.value.ip_tag == null ? [] : public_ip_address.value.ip_tag

                content {
                  tag  = ip_tag.value.tag
                  type = ip_tag.value.type
                }
              }
            }
          }
        }
      }
    }
  }
  dynamic "os_disk" {
    for_each = var.os_disk == null ? [] : [var.os_disk]

    content {
      caching                   = os_disk.value.caching
      storage_account_type      = os_disk.value.storage_account_type
      disk_encryption_set_id    = os_disk.value.disk_encryption_set_id
      disk_size_gb              = os_disk.value.disk_size_gb
      write_accelerator_enabled = os_disk.value.write_accelerator_enabled

      dynamic "diff_disk_settings" {
        for_each = os_disk.value.diff_disk_settings == null ? [] : [os_disk.value.diff_disk_settings]

        content {
          option    = diff_disk_settings.value.option
          placement = diff_disk_settings.value.placement
        }
      }
    }
  }
  dynamic "os_profile" {
    for_each = var.os_profile == null ? [] : [var.os_profile]

    content {
      custom_data = os_profile.value.custom_data

      dynamic "linux_configuration" {
        for_each = os_profile.value.linux_configuration == null ? [] : [os_profile.value.linux_configuration]

        content {
          admin_username                  = linux_configuration.value.admin_username
          admin_password                  = var.admin_password
          computer_name_prefix            = linux_configuration.value.computer_name_prefix
          disable_password_authentication = linux_configuration.value.disable_password_authentication
          patch_assessment_mode           = linux_configuration.value.patch_assessment_mode
          patch_mode                      = linux_configuration.value.patch_mode
          provision_vm_agent              = linux_configuration.value.provision_vm_agent

          dynamic "admin_ssh_key" {
            for_each = linux_configuration.value.admin_ssh_key_id == null ? [] : linux_configuration.value.admin_ssh_key_id

            content {
              public_key = lookup(
                { for key in var.admin_ssh_keys : key.id => key.public_key },
                admin_ssh_key.value,
                null
              )
              username = lookup(
                { for key in var.admin_ssh_keys : key.id => key.username },
                admin_ssh_key.value,
                null
              )
            }
          }
          dynamic "secret" {
            for_each = linux_configuration.value.secret == null ? [] : linux_configuration.value.secret

            content {
              key_vault_id = secret.value.key_vault_id

              dynamic "certificate" {
                for_each = secret.value.certificate == null ? [] : secret.value.certificate

                content {
                  url = certificate.value.url
                }
              }
            }
          }
        }
      }
      dynamic "windows_configuration" {
        for_each = os_profile.value.windows_configuration == null ? [] : [os_profile.value.windows_configuration]

        content {
          admin_password           = var.admin_password
          admin_username           = windows_configuration.value.admin_username
          computer_name_prefix     = windows_configuration.value.computer_name_prefix
          enable_automatic_updates = windows_configuration.value.enable_automatic_updates
          hotpatching_enabled      = windows_configuration.value.hotpatching_enabled
          patch_assessment_mode    = windows_configuration.value.patch_assessment_mode
          patch_mode               = windows_configuration.value.patch_mode
          provision_vm_agent       = windows_configuration.value.provision_vm_agent
          timezone                 = windows_configuration.value.timezone

          dynamic "secret" {
            for_each = windows_configuration.value.secret == null ? [] : windows_configuration.value.secret

            content {
              key_vault_id = secret.value.key_vault_id

              dynamic "certificate" {
                for_each = secret.value.certificate == null ? [] : secret.value.certificate

                content {
                  store = certificate.value.store
                  url   = certificate.value.url
                }
              }
            }
          }
          dynamic "winrm_listener" {
            for_each = windows_configuration.value.winrm_listener == null ? [] : windows_configuration.value.winrm_listener

            content {
              protocol        = winrm_listener.value.protocol
              certificate_url = winrm_listener.value.certificate_url
            }
          }
        }
      }
    }
  }
  dynamic "plan" {
    for_each = var.plan == null ? [] : [var.plan]

    content {
      name      = plan.value.name
      product   = plan.value.product
      publisher = plan.value.publisher
    }
  }
  dynamic "priority_mix" {
    for_each = var.priority_mix == null ? [] : [var.priority_mix]

    content {
      base_regular_count            = priority_mix.value.base_regular_count
      regular_percentage_above_base = priority_mix.value.regular_percentage_above_base
    }
  }
  dynamic "source_image_reference" {
    for_each = var.source_image_reference == null ? [] : [var.source_image_reference]

    content {
      offer     = source_image_reference.value.offer
      publisher = source_image_reference.value.publisher
      sku       = source_image_reference.value.sku
      version   = source_image_reference.value.version
    }
  }
  dynamic "termination_notification" {
    for_each = var.termination_notification == null ? [] : [var.termination_notification]

    content {
      enabled = termination_notification.value.enabled
      timeout = termination_notification.value.timeout
    }
  }
  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

resource "azapi_update_resource" "set_update_policy" {
  type = "Microsoft.Compute/virtualMachineScaleSets@2024-07-01"

  body = merge(
    # Only include upgradePolicy if it's not "Rolling"
    var.upgrade_policy.upgrade_mode != "Rolling" ? {
      properties = {
        upgradePolicy = {
          mode = var.upgrade_policy.upgrade_mode
        }
      }
    } : {},

    # If the upgrade mode is "Rolling", include the rolling upgrade policy settings
    var.upgrade_policy.upgrade_mode == "Rolling" ? {
      properties = {
        upgradePolicy = {
          mode = var.upgrade_policy.upgrade_mode
          rollingUpgradePolicy = {
            maxBatchInstancePercent             = var.upgrade_policy.rolling_upgrade_policy.max_batch_instance_percent
            maxUnhealthyInstancePercent         = var.upgrade_policy.rolling_upgrade_policy.max_unhealthy_instance_percent
            maxUnhealthyUpgradedInstancePercent = var.upgrade_policy.rolling_upgrade_policy.max_unhealthy_upgraded_instance_percent
            pauseTimeBetweenBatches             = var.upgrade_policy.rolling_upgrade_policy.pause_time_between_batches
            maxSurge                            = var.upgrade_policy.rolling_upgrade_policy.maximum_surge_instances_enabled
          }
        }
      }
    } : {}
  )

  resource_id = azurerm_orchestrated_virtual_machine_scale_set.virtual_machine_scale_set.id
}


# AVM Required Code

resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azurerm_orchestrated_virtual_machine_scale_set.virtual_machine_scale_set.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  principal_id                           = each.value.principal_id
  scope                                  = azurerm_orchestrated_virtual_machine_scale_set.virtual_machine_scale_set.id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  principal_type                         = each.value.principal_type
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}

