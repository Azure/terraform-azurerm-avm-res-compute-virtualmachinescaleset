data "azapi_client_config" "current" {}

# Data source to read existing VMSS for drift detection
# This is used to detect when zones are removed (requires recreation) or
# single_placement_group changes from false to true (not allowed - throws error)
data "azapi_resource" "existing_vmss" {
  name                   = var.name
  parent_id              = "/subscriptions/${data.azapi_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  type                   = "Microsoft.Compute/virtualMachineScaleSets@2024-11-01"
  ignore_not_found       = true
  response_export_values = ["*"]

  lifecycle {
    postcondition {
      condition = !(
        self.exists &&
        try(self.output.sku, null) != null &&
        try(self.output.properties.virtualMachineProfile, null) == null
      )
      error_message = "Existing VMSS must have `properties.virtualMachineProfile` defined for non-legacy scale sets."
    }
    postcondition {
      condition = !(
        self.exists &&
        try(self.output.sku, null) != null &&
        try(self.output.properties.virtualMachineProfile.storageProfile, null) == null
      )
      error_message = "Existing VMSS must have `properties.virtualMachineProfile.storageProfile` defined for non-legacy scale sets."
    }
  }
}

moved {
  from = azurerm_orchestrated_virtual_machine_scale_set.virtual_machine_scale_set
  to   = azapi_resource.virtual_machine_scale_set
}

resource "azapi_resource" "virtual_machine_scale_set" {
  location  = var.location
  name      = var.name
  parent_id = local.resource_group_id
  type      = "Microsoft.Compute/virtualMachineScaleSets@2025-04-01"
  body = merge(
    {
      sku = {
        capacity = var.instances
        name     = var.sku_name
        tier     = var.sku_name != "Mix" ? "Standard" : null
      }
      properties = merge(
        data.azapi_resource.existing_vmss.exists ? {
          constrainedMaximumCapacity = data.azapi_resource.existing_vmss.output.properties.constrainedMaximumCapacity
        } : {},
        {
          highSpeedInterconnectPlacement = "None"
          orchestrationMode              = "Flexible"
          singlePlacementGroup           = false
        },
        {
          platformFaultDomainCount = var.platform_fault_domain_count
        },
        var.proximity_placement_group_id != null ? {
          proximityPlacementGroup = {
            id = var.proximity_placement_group_id
          }
        } : {},
        var.single_placement_group != null ? {
          singlePlacementGroup = var.single_placement_group
        } : {},
        var.zone_balance != null ? {
          zoneBalance = var.zone_balance
        } : {},
        var.upgrade_policy != null && var.upgrade_policy.upgrade_mode != null ? {
          upgradePolicy = merge(
            {
              mode = var.upgrade_policy.upgrade_mode
            },
            var.upgrade_policy.upgrade_mode == "Rolling" && var.upgrade_policy.rolling_upgrade_policy != null ? {
              rollingUpgradePolicy = merge(
                {
                  maxBatchInstancePercent             = var.upgrade_policy.rolling_upgrade_policy.max_batch_instance_percent
                  maxUnhealthyInstancePercent         = var.upgrade_policy.rolling_upgrade_policy.max_unhealthy_instance_percent
                  maxUnhealthyUpgradedInstancePercent = var.upgrade_policy.rolling_upgrade_policy.max_unhealthy_upgraded_instance_percent
                  pauseTimeBetweenBatches             = var.upgrade_policy.rolling_upgrade_policy.pause_time_between_batches
                },
                var.upgrade_policy.rolling_upgrade_policy.cross_zone_upgrades_enabled != null ? {
                  enableCrossZoneUpgrade = var.upgrade_policy.rolling_upgrade_policy.cross_zone_upgrades_enabled
                } : {},
                var.upgrade_policy.rolling_upgrade_policy.maximum_surge_instances_enabled != null ? {
                  maxSurge = var.upgrade_policy.rolling_upgrade_policy.maximum_surge_instances_enabled
                } : {},
                var.upgrade_policy.rolling_upgrade_policy.prioritize_unhealthy_instances_enabled != null ? {
                  prioritizeUnhealthyInstances = var.upgrade_policy.rolling_upgrade_policy.prioritize_unhealthy_instances_enabled
                } : {}
              )
            } : {}
          )
        } : {},
        var.additional_capabilities != null ? {
          additionalCapabilities = {
            ultraSSDEnabled = var.additional_capabilities.ultra_ssd_enabled
          }
        } : {},
        var.automatic_instance_repair != null ? {
          automaticRepairsPolicy = merge(
            {
              enabled = var.automatic_instance_repair.enabled
            },
            var.automatic_instance_repair.grace_period != null ? {
              gracePeriod = var.automatic_instance_repair.grace_period
            } : {}
          )
        } : {},
        var.priority_mix != null ? {
          priorityMixPolicy = merge(
            var.priority_mix.base_regular_count != null ? {
              baseRegularPriorityCount = var.priority_mix.base_regular_count
            } : {},
            var.priority_mix.regular_percentage_above_base != null ? {
              regularPriorityPercentageAboveBase = var.priority_mix.regular_percentage_above_base
            } : {}
          )
        } : {},
        {
          virtualMachineProfile = merge(
            var.capacity_reservation_group_id != null ? {
              capacityReservation = {
                capacityReservationGroup = {
                  id = var.capacity_reservation_group_id
                }
              }
            } : {},
            var.encryption_at_host_enabled != null ? {
              securityProfile = {
                encryptionAtHost = var.encryption_at_host_enabled
              }
            } : {},
            var.eviction_policy != null ? {
              evictionPolicy = var.eviction_policy
            } : {},
            try(length(var.extension) > 0, false) || var.extensions_time_budget != null ? {
              extensionProfile = merge(
                var.extensions_time_budget != null ? {
                  extensionsTimeBudget = var.extensions_time_budget
                } : {},
                try(length(var.extension) > 0, false) ? {
                  extensions = [
                    for ext in var.extension : {
                      name = ext.name
                      properties = merge(
                        {
                          publisher          = ext.publisher
                          type               = ext.type
                          typeHandlerVersion = ext.type_handler_version
                        },
                        ext.auto_upgrade_minor_version_enabled != null ? {
                          autoUpgradeMinorVersion = ext.auto_upgrade_minor_version_enabled
                        } : {},
                        ext.failure_suppression_enabled != null ? {
                          suppressFailures = ext.failure_suppression_enabled
                        } : {},
                        ext.force_extension_execution_on_change != null ? {
                          forceUpdateTag = ext.force_extension_execution_on_change != null ? ext.force_extension_execution_on_change : ""
                        } : {},
                        ext.settings != null && ext.settings != "" ? {
                          settings = jsondecode(ext.settings)
                        } : {},
                        ext.extensions_to_provision_after_vm_creation != null ? {
                          provisionAfterExtensions = ext.extensions_to_provision_after_vm_creation
                        } : {},
                        ext.protected_settings_from_key_vault != null ? {
                          protectedSettingsFromKeyVault = {
                            secretUrl = ext.protected_settings_from_key_vault.secret_url
                            sourceVault = {
                              id = ext.protected_settings_from_key_vault.source_vault_id
                            }
                          }
                        } : {}
                      )
                    }
                  ]
                } : {}
              )
            } : {},
            var.extension_operations_enabled != null || var.os_profile != null ? {
              osProfile = merge(
                data.azapi_resource.existing_vmss.exists ? {
                  requireGuestProvisionSignal = try(data.azapi_resource.existing_vmss.output.properties.virtualMachineProfile.osProfile.requireGuestProvisionSignal, true)
                } : {},
                var.extension_operations_enabled != null ? {
                  allowExtensionOperations = var.extension_operations_enabled
                } : {},
                # adminUsername, adminPassword, computerNamePrefix belong at osProfile level for both Linux and Windows
                var.os_profile != null && var.os_profile.linux_configuration != null && var.os_profile.linux_configuration.admin_username != null ? {
                  adminUsername = var.os_profile.linux_configuration.admin_username
                  } : var.os_profile != null && var.os_profile.windows_configuration != null && var.os_profile.windows_configuration.admin_username != null ? {
                  adminUsername = var.os_profile.windows_configuration.admin_username
                } : {},
                var.os_profile != null && (var.os_profile.linux_configuration != null || var.os_profile.windows_configuration != null) ? {
                  computerNamePrefix = local.default_computer_name_prefix
                } : {},
                # secrets belong at osProfile level
                # Always set secrets to match Azure API behavior (returns empty array when no secrets are configured)
                var.os_profile != null && var.os_profile.linux_configuration != null ? {
                  secrets = var.os_profile.linux_configuration.secret != null && length(var.os_profile.linux_configuration.secret) > 0 ? [
                    for secret in var.os_profile.linux_configuration.secret : {
                      sourceVault = {
                        id = secret.key_vault_id
                      }
                      vaultCertificates = [
                        for cert in secret.certificate : {
                          certificateUrl = cert.url
                        }
                      ]
                    }
                  ] : []
                  } : var.os_profile != null && var.os_profile.windows_configuration != null ? {
                  secrets = var.os_profile.windows_configuration.secret != null && length(var.os_profile.windows_configuration.secret) > 0 ? [
                    for secret in var.os_profile.windows_configuration.secret : {
                      sourceVault = {
                        id = secret.key_vault_id
                      }
                      vaultCertificates = [
                        for cert in secret.certificate : {
                          certificateStore = cert.store
                          certificateUrl   = cert.url
                        }
                      ]
                    }
                  ] : []
                } : {},
                # linuxConfiguration - OS-specific settings only
                var.os_profile != null && var.os_profile.linux_configuration != null ? {
                  linuxConfiguration = merge(
                    {
                      disablePasswordAuthentication = var.os_profile.linux_configuration.disable_password_authentication != null ? var.os_profile.linux_configuration.disable_password_authentication : true
                    },
                    {
                      patchSettings = {
                        assessmentMode = var.os_profile.linux_configuration.patch_assessment_mode
                        patchMode      = var.os_profile.linux_configuration.patch_mode
                      }
                    },
                    var.os_profile.linux_configuration.provision_vm_agent != null ? {
                      provisionVMAgent = var.os_profile.linux_configuration.provision_vm_agent
                    } : {},
                    var.os_profile.linux_configuration.admin_ssh_key_id != null && length(var.os_profile.linux_configuration.admin_ssh_key_id) > 0 ? {
                      ssh = {
                        publicKeys = [
                          for ssh_key_id in var.os_profile.linux_configuration.admin_ssh_key_id : {
                            path    = "/home/${try(local.ssh_keys_map[ssh_key_id].username, "")}/.ssh/authorized_keys"
                            keyData = try(local.ssh_keys_map[ssh_key_id].public_key, "")
                          }
                        ]
                      }
                    } : {}
                  )
                } : {},
                # windowsConfiguration - OS-specific settings only
                var.os_profile != null && var.os_profile.windows_configuration != null ? {
                  windowsConfiguration = merge(
                    {
                      enableAutomaticUpdates = var.os_profile.windows_configuration.enable_automatic_updates != null ? var.os_profile.windows_configuration.enable_automatic_updates : false
                    },
                    var.os_profile.windows_configuration.hotpatching_enabled != null ? {
                      patchSettings = {
                        enableHotpatching = var.os_profile.windows_configuration.hotpatching_enabled
                        assessmentMode    = var.os_profile.windows_configuration.patch_assessment_mode
                        patchMode         = var.os_profile.windows_configuration.patch_mode
                      }
                      } : var.os_profile.windows_configuration.patch_assessment_mode != null || var.os_profile.windows_configuration.patch_mode != null ? {
                      patchSettings = merge(
                        {
                          enableHotpatching = null
                        },
                        var.os_profile.windows_configuration.patch_assessment_mode != null ? {
                          assessmentMode = var.os_profile.windows_configuration.patch_assessment_mode
                        } : {},
                        var.os_profile.windows_configuration.patch_mode != null ? {
                          patchMode = var.os_profile.windows_configuration.patch_mode
                        } : {}
                      )
                    } : {},
                    var.os_profile.windows_configuration.provision_vm_agent != null ? {
                      provisionVMAgent = var.os_profile.windows_configuration.provision_vm_agent
                    } : {},
                    var.os_profile.windows_configuration.timezone != null ? {
                      timeZone = var.os_profile.windows_configuration.timezone
                    } : {},
                    var.os_profile.windows_configuration.winrm_listener != null && length(var.os_profile.windows_configuration.winrm_listener) > 0 ? {
                      winRM = {
                        listeners = [
                          for listener in var.os_profile.windows_configuration.winrm_listener : merge(
                            {
                              protocol = listener.protocol
                            },
                            listener.certificate_url != null ? {
                              certificateUrl = listener.certificate_url
                            } : {}
                          )
                        ]
                      }
                    } : {}
                  )
                } : {}
              )
            } : {},
            local.normalized_license_type != null ? {
              licenseType = local.normalized_license_type
            } : {},
            var.max_bid_price != null && var.max_bid_price > 0 ? {
              billingProfile = {
                maxPrice = var.max_bid_price
              }
            } : {},
            var.priority != null ? {
              priority = var.priority
            } : {},
            var.source_image_id != null ? {
              storageProfile = {
                imageReference = {
                  id = var.source_image_id
                }
              }
              } : var.source_image_reference != null ? {
              storageProfile = {
                imageReference = {
                  offer     = var.source_image_reference.offer
                  publisher = var.source_image_reference.publisher
                  sku       = var.source_image_reference.sku
                  version   = var.source_image_reference.version
                }
              }
            } : {},
            var.network_interface != null && length(var.network_interface) > 0 ? {
              networkProfile = {
                networkApiVersion = var.network_api_version
                networkInterfaceConfigurations = [
                  for nic in var.network_interface : {
                    name = nic.name
                    properties = merge(
                      {
                        auxiliaryMode           = "None"
                        auxiliarySku            = "None"
                        deleteOption            = "Delete"
                        disableTcpStateTracking = false
                        ipConfigurations = [
                          for ip_config in nic.ip_configuration : merge(
                            {
                              name = ip_config.name
                              properties = merge(
                                ip_config.application_gateway_backend_address_pool_ids != null ? {
                                  applicationGatewayBackendAddressPools = [
                                    for pool_id in ip_config.application_gateway_backend_address_pool_ids : {
                                      id = pool_id
                                    }
                                  ]
                                } : {},
                                ip_config.application_security_group_ids != null ? {
                                  applicationSecurityGroups = [
                                    for asg_id in ip_config.application_security_group_ids : {
                                      id = asg_id
                                    }
                                  ]
                                } : {},
                                ip_config.load_balancer_backend_address_pool_ids != null ? {
                                  loadBalancerBackendAddressPools = [
                                    for pool_id in ip_config.load_balancer_backend_address_pool_ids : {
                                      id = pool_id
                                    }
                                  ]
                                } : {},
                                ip_config.primary != null ? {
                                  primary = ip_config.primary
                                } : {},
                                ip_config.subnet_id != null ? {
                                  subnet = {
                                    id = ip_config.subnet_id
                                  }
                                } : {},
                                ip_config.version != null ? {
                                  privateIPAddressVersion = ip_config.version
                                } : {},
                                ip_config.public_ip_address != null && length(ip_config.public_ip_address) > 0 ? {
                                  publicIPAddressConfiguration = {
                                    name = ip_config.public_ip_address[0].name
                                    properties = merge(
                                      {
                                      },
                                      ip_config.public_ip_address[0].domain_name_label != null ? {
                                        dnsSettings = {
                                          domainNameLabel = ip_config.public_ip_address[0].domain_name_label
                                        }
                                      } : {},
                                      ip_config.public_ip_address[0].idle_timeout_in_minutes != null ? {
                                        idleTimeoutInMinutes = ip_config.public_ip_address[0].idle_timeout_in_minutes
                                      } : {},
                                      ip_config.public_ip_address[0].ip_tag != null && length(ip_config.public_ip_address[0].ip_tag) > 0 ? {
                                        ipTags = [
                                          for tag in ip_config.public_ip_address[0].ip_tag : {
                                            ipTagType = tag.type
                                            tag       = tag.tag
                                          }
                                        ]
                                      } : {},
                                      ip_config.public_ip_address[0].public_ip_prefix_id != null ? {
                                        publicIPPrefix = {
                                          id = ip_config.public_ip_address[0].public_ip_prefix_id
                                        }
                                      } : {},
                                      ip_config.public_ip_address[0].version != null ? {
                                        publicIPAddressVersion = ip_config.public_ip_address[0].version
                                      } : {}
                                    )
                                    sku = ip_config.public_ip_address[0].sku_name != null ? {
                                      name = ip_config.public_ip_address[0].sku_name
                                    } : null
                                  }
                                } : {}
                              )
                            }
                          )
                        ]
                      },
                      nic.dns_servers != null ? {
                        dnsSettings = {
                          dnsServers = nic.dns_servers
                        }
                      } : {},
                      nic.enable_accelerated_networking != null ? {
                        enableAcceleratedNetworking = nic.enable_accelerated_networking
                      } : {},
                      nic.enable_ip_forwarding != null ? {
                        enableIPForwarding = nic.enable_ip_forwarding
                      } : {},
                      nic.network_security_group_id != null ? {
                        networkSecurityGroup = {
                          id = nic.network_security_group_id
                        }
                      } : {},
                      {
                        primary = nic.primary
                      },
                    )
                  }
                ]
              }
            } : {},
            var.boot_diagnostics != null ? {
              diagnosticsProfile = {
                bootDiagnostics = merge(
                  {
                    enabled = true
                  },
                  var.boot_diagnostics.storage_account_uri != null && var.boot_diagnostics.storage_account_uri != "" ? {
                    storageUri = var.boot_diagnostics.storage_account_uri
                    } : {
                  }
                )
              }
            } : {},
            var.os_disk != null || (var.data_disk != null && length(var.data_disk) > 0) ? {
              storageProfile = merge(
                var.disk_controller_type != null ? {
                  diskControllerType = var.disk_controller_type
                  } : local.is_linux ? {
                  diskControllerType = "SCSI"
                } : {},
                var.source_image_id != null ? {
                  imageReference = {
                    id = var.source_image_id
                  }
                  } : var.source_image_reference != null ? {
                  imageReference = {
                    offer     = var.source_image_reference.offer
                    publisher = var.source_image_reference.publisher
                    sku       = var.source_image_reference.sku
                    version   = var.source_image_reference.version
                  }
                } : {},
                var.os_disk != null ? {
                  osDisk = merge(
                    {
                      createOption = "FromImage"
                      deleteOption = var.os_disk.delete_option
                      osType       = local.is_linux ? "Linux" : "Windows"
                    },
                    {
                      caching = var.os_disk.caching
                      managedDisk = merge(
                        {
                          storageAccountType = var.os_disk.storage_account_type
                        },
                        var.os_disk.disk_encryption_set_id != null ? {
                          diskEncryptionSet = {
                            id = var.os_disk.disk_encryption_set_id
                          }
                        } : {}
                      )
                    },
                    {
                      diskSizeGB = var.os_disk.disk_size_gb != null ? var.os_disk.disk_size_gb : (local.is_windows ? 127 : 30)
                    },
                    {
                      writeAcceleratorEnabled = var.os_disk.write_accelerator_enabled
                    },
                    var.os_disk.diff_disk_settings != null ? {
                      diffDiskSettings = merge(
                        {
                          option = var.os_disk.diff_disk_settings.option
                        },
                        var.os_disk.diff_disk_settings.placement != null ? {
                          placement = var.os_disk.diff_disk_settings.placement
                        } : {}
                      )
                    } : {}
                  )
                } : {},
                var.data_disk != null && length(var.data_disk) > 0 ? {
                  dataDisks = [
                    for dd in var.data_disk : merge(
                      {
                        caching      = dd.caching
                        deleteOption = dd.delete_option != null ? dd.delete_option : "Delete"
                        managedDisk = merge(
                          {
                            storageAccountType = dd.storage_account_type
                          },
                          dd.disk_encryption_set_id != null ? {
                            diskEncryptionSet = {
                              id = dd.disk_encryption_set_id
                            }
                          } : {}
                        )
                      },
                      dd.lun != null && dd.lun >= 0 ? {
                        lun = dd.lun
                      } : {},
                      dd.create_option != null ? {
                        createOption = dd.create_option
                      } : {},
                      dd.disk_size_gb != null ? {
                        diskSizeGB = dd.disk_size_gb
                      } : {},
                      dd.ultra_ssd_disk_iops_read_write != null ? {
                        diskIOPSReadWrite = dd.ultra_ssd_disk_iops_read_write
                      } : {},
                      dd.ultra_ssd_disk_mbps_read_write != null ? {
                        diskMBpsReadWrite = dd.ultra_ssd_disk_mbps_read_write
                      } : {},
                      dd.write_accelerator_enabled != null ? {
                        writeAcceleratorEnabled = dd.write_accelerator_enabled
                      } : {}
                    )
                  ]
                } : {}
              )
            } : {},
            var.termination_notification != null ? {
              scheduledEventsProfile = {
                terminateNotificationProfile = merge(
                  {
                    enable = var.termination_notification.enabled
                  },
                  var.termination_notification.timeout != null ? {
                    notBeforeTimeout = var.termination_notification.timeout
                  } : {}
                )
              }
            } : {}
          )
        }
      )
    },
    var.zones != null && length(var.zones) > 0 ? {
      zones = sort(tolist(var.zones))
    } : {},
    var.plan != null ? {
      plan = {
        name      = var.plan.name
        product   = var.plan.product
        publisher = var.plan.publisher
      }
    } : {}
  )
  create_headers       = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers       = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  ignore_null_property = true
  read_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  # Force recreation when zones are removed
  # Adding zones is allowed (update in-place), but removing zones requires recreation
  # This mimics azurerm provider behavior
  replace_triggers_external_values = {
    zones_removal_trigger          = local.zones_replacement_trigger
    single_placement_group_trigger = local.single_placement_group_trigger
  }
  # Sensitive body for write-only properties
  sensitive_body = {
    properties = {
      virtualMachineProfile = merge(
        var.admin_password != null || var.custom_data != null ? {
          osProfile = merge(
            var.admin_password != null ? {
              adminPassword = var.admin_password
            } : {},
            var.custom_data != null ? {
              customData = var.custom_data
            } : {}
          )
        } : {},
        var.user_data_base64 != null ? {
          userData = var.user_data_base64
        } : {},
        try(length(var.extension_protected_setting) > 0, false) && try(length(var.extension) > 0, false) ? {
          extensionProfile = {
            extensions = [
              for ext in var.extension : {
                name = ext.name
                properties = lookup(var.extension_protected_setting, ext.name, "") != "" ? {
                  protectedSettings = jsondecode(lookup(var.extension_protected_setting, ext.name, ""))
                } : {}
              }
            ]
          }
        } : {}
      )
    }
  }
  # Version tracking for sensitive properties
  sensitive_body_version = merge(
    var.admin_password_version != null ? {
      "properties.virtualMachineProfile.osProfile.adminPassword" = var.admin_password_version
    } : {},
    var.custom_data_version != null ? {
      "properties.virtualMachineProfile.osProfile.customData" = var.custom_data_version
    } : {},
    var.user_data_base64_version != null ? {
      "properties.virtualMachineProfile.userData" = var.user_data_base64_version
    } : {},
    var.extension_protected_setting_version != null ? {
      for ext_name, version in var.extension_protected_setting_version :
      "properties.virtualMachineProfile.extensionProfile.extensions[?name=='${ext_name}'].properties.protectedSettings" => version
    } : {}
  )
  tags           = var.tags
  update_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

  # Managed identity configuration - must be at resource level, not in body
  dynamic "identity" {
    for_each = local.managed_identities != null ? [local.managed_identities] : []

    content {
      type         = identity.value.type
      identity_ids = identity.value.identity_ids
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

  lifecycle {
    ignore_changes = [
      body.properties.virtualMachineProfile.osProfile.requireGuestProvisionSignal,
      body.zones,
    ]

    precondition {
      condition     = var.zone_balance != true || (var.zones != null && length(var.zones) > 0)
      error_message = "`zone_balance` can only be set to `true` when availability zones are specified."
    }
    precondition {
      condition     = var.upgrade_policy == null || var.upgrade_policy.upgrade_mode != "Rolling" || (var.upgrade_policy.rolling_upgrade_policy != null && var.upgrade_policy.rolling_upgrade_policy.max_batch_instance_percent != null && var.upgrade_policy.rolling_upgrade_policy.max_unhealthy_instance_percent != null && var.upgrade_policy.rolling_upgrade_policy.max_unhealthy_upgraded_instance_percent != null && var.upgrade_policy.rolling_upgrade_policy.pause_time_between_batches != null)
      error_message = "`rolling_upgrade_policy` with all required properties (max_batch_instance_percent, max_unhealthy_instance_percent, max_unhealthy_upgraded_instance_percent, pause_time_between_batches) must be specified when `upgrade_mode` is set to `Rolling`."
    }
    precondition {
      condition     = var.eviction_policy == null || var.priority == "Spot"
      error_message = "`eviction_policy` can only be specified when `priority` is set to `Spot`."
    }
    precondition {
      condition     = var.priority != "Spot" || var.eviction_policy != null
      error_message = "`eviction_policy` is required when `priority` is set to `Spot`."
    }
    precondition {
      condition = local.computer_name_prefix_valid
      error_message = local.is_windows ? (
        "When using Windows, the computer name prefix '${local.default_computer_name_prefix}' is invalid. It must be at most 9 characters, contain only alphanumeric characters and hyphens, and cannot contain only numbers. Please adjust the `name`, or specify an explicit `computer_name_prefix`."
        ) : local.is_linux ? (
        "When using Linux, the computer name prefix '${local.default_computer_name_prefix}' is invalid. It must be at most 58 characters, cannot begin with an underscore, cannot end with a period, and cannot contain special characters (\\\"[]:|<>+=;,?*@&~!#$$%^()_{}). Please adjust the `name`, or specify an explicit `computer_name_prefix`."
      ) : "Computer name prefix validation failed."
    }
    precondition {
      condition     = var.capacity_reservation_group_id == null || var.single_placement_group != true
      error_message = "`single_placement_group` must be set to `false` when `capacity_reservation_group_id` is specified."
    }
    precondition {
      condition     = var.upgrade_policy == null || var.upgrade_policy.upgrade_mode != "Rolling" || local.has_health_extension
      error_message = "Health extension is required when `upgrade_mode` is set to `Rolling`."
    }
    precondition {
      condition     = var.automatic_instance_repair == null || local.has_health_extension
      error_message = "`automatic_instance_repair` can only be enabled when an application health extension is configured."
    }
    precondition {
      condition = (
        var.os_profile == null ||
        var.os_profile.linux_configuration == null ||
        var.os_profile.linux_configuration.patch_mode != "AutomaticByPlatform" ||
        local.has_health_extension
      )
      error_message = "When `patch_mode` is set to `AutomaticByPlatform` for Linux, at least one application health extension must be configured."
    }
    precondition {
      condition = (
        var.os_profile == null ||
        var.os_profile.windows_configuration == null ||
        var.os_profile.windows_configuration.patch_mode != "AutomaticByPlatform" ||
        local.has_health_extension
      )
      error_message = "When `patch_mode` is set to `AutomaticByPlatform` for Windows, an application health extension must be configured."
    }
    # Hotpatching validation for hotpatch-enabled images
    precondition {
      condition = (
        !local.is_hotpatch_enabled_image ||
        var.os_profile == null ||
        var.os_profile.windows_configuration == null ||
        var.os_profile.windows_configuration.patch_mode == "AutomaticByPlatform"
      )
      error_message = "When using a hotpatching enabled image, `patch_mode` must be set to `AutomaticByPlatform`."
    }
    precondition {
      condition = (
        !local.is_hotpatch_enabled_image ||
        var.os_profile == null ||
        var.os_profile.windows_configuration == null ||
        var.os_profile.windows_configuration.provision_vm_agent != false
      )
      error_message = "When using a hotpatching enabled image, `provision_vm_agent` must be set to `true`."
    }
    precondition {
      condition = (
        !local.is_hotpatch_enabled_image ||
        var.os_profile == null ||
        var.os_profile.windows_configuration == null ||
        local.has_health_extension
      )
      error_message = "When using a hotpatching enabled image, an application health extension must be configured."
    }
    precondition {
      condition = (
        !local.is_hotpatch_enabled_image ||
        var.os_profile == null ||
        var.os_profile.windows_configuration == null ||
        var.os_profile.windows_configuration.hotpatching_enabled == true
      )
      error_message = "When using a hotpatching enabled image, `hotpatching_enabled` must be set to `true`."
    }
    # Hotpatching validation when hotpatching_enabled is true but image doesn't support it
    precondition {
      condition = (
        var.os_profile == null ||
        var.os_profile.windows_configuration == null ||
        var.os_profile.windows_configuration.hotpatching_enabled != true ||
        local.is_hotpatch_enabled_image
      )
      error_message = "`hotpatching_enabled` can only be used with supported Windows Server images: '2022-datacenter-azure-edition-core', '2022-datacenter-azure-edition-core-smalldisk', '2022-datacenter-azure-edition-hotpatch', '2022-datacenter-azure-edition-hotpatch-smalldisk', '2025-datacenter-azure-edition', '2025-datacenter-azure-edition-smalldisk', '2025-datacenter-azure-edition-core', or '2025-datacenter-azure-edition-core-smalldisk' from MicrosoftWindowsServer/WindowsServer."
    }
    # Windows: extension_operations_enabled requires provision_vm_agent
    precondition {
      condition = (
        var.extension_operations_enabled != true ||
        var.os_profile == null ||
        var.os_profile.windows_configuration == null ||
        var.os_profile.windows_configuration.provision_vm_agent != false
      )
      error_message = "`extension_operations_enabled` cannot be set to `true` when `provision_vm_agent` is set to `false` for Windows."
    }
    # Linux: extension_operations_enabled requires provision_vm_agent
    precondition {
      condition = (
        var.extension_operations_enabled != true ||
        var.os_profile == null ||
        var.os_profile.linux_configuration == null ||
        var.os_profile.linux_configuration.provision_vm_agent != false
      )
      error_message = "`extension_operations_enabled` cannot be set to `true` when `provision_vm_agent` is set to `false` for Linux."
    }
    # Windows: patch_assessment_mode AutomaticByPlatform requires provision_vm_agent
    precondition {
      condition = (
        var.os_profile == null ||
        var.os_profile.windows_configuration == null ||
        var.os_profile.windows_configuration.patch_assessment_mode != "AutomaticByPlatform" ||
        var.os_profile.windows_configuration.provision_vm_agent != false
      )
      error_message = "When `patch_assessment_mode` is set to `AutomaticByPlatform` for Windows, `provision_vm_agent` must be set to `true`."
    }
    # Windows: patch_mode AutomaticByPlatform requires provision_vm_agent
    precondition {
      condition = (
        var.os_profile == null ||
        var.os_profile.windows_configuration == null ||
        var.os_profile.windows_configuration.patch_mode != "AutomaticByPlatform" ||
        var.os_profile.windows_configuration.provision_vm_agent != false
      )
      error_message = "When `patch_mode` is set to `AutomaticByPlatform` for Windows, `provision_vm_agent` must be set to `true`."
    }
    # Linux: patch_assessment_mode AutomaticByPlatform requires provision_vm_agent
    precondition {
      condition = (
        var.os_profile == null ||
        var.os_profile.linux_configuration == null ||
        var.os_profile.linux_configuration.patch_assessment_mode != "AutomaticByPlatform" ||
        var.os_profile.linux_configuration.provision_vm_agent != false
      )
      error_message = "When `patch_assessment_mode` is set to `AutomaticByPlatform` for Linux, `provision_vm_agent` must be set to `true`."
    }
    # Linux: patch_mode AutomaticByPlatform requires provision_vm_agent
    precondition {
      condition = (
        var.os_profile == null ||
        var.os_profile.linux_configuration == null ||
        var.os_profile.linux_configuration.patch_mode != "AutomaticByPlatform" ||
        var.os_profile.linux_configuration.provision_vm_agent != false
      )
      error_message = "When `patch_mode` is set to `AutomaticByPlatform` for Linux, `provision_vm_agent` must be set to `true`."
    }
    # max_bid_price requires priority = Spot
    precondition {
      condition = (
        var.max_bid_price == null ||
        var.max_bid_price <= 0 ||
        var.priority == "Spot"
      )
      error_message = "`max_bid_price` can only be configured when `priority` is set to `Spot`."
    }
    # priority_mix requires priority = Spot
    precondition {
      condition = (
        var.priority_mix == null ||
        var.priority == "Spot"
      )
      error_message = "`priority_mix` can only be specified when `priority` is set to `Spot`."
    }
  }
}

# Terraform data resource to track changes that require updates via azapi_update_resource
# This triggers replacement when tracked values change, which then triggers the azapi_update_resource
resource "terraform_data" "update_tracker" {
  input = {
    zones = var.zones != null && length(var.zones) > 0 ? sort(tolist(var.zones)) : []
    # Add more fields here as needed to track additional properties that require updates
  }
}

moved {
  from = azapi_update_resource.set_vmss_license
  to   = azapi_update_resource.this
}

# Update resource properties using azapi_update_resource to maintain idempotency
# This is necessary because certain properties are ignored in the main resource to prevent drift
# while still allowing updates to be applied when explicitly changed
resource "azapi_update_resource" "this" {
  resource_id = azapi_resource.virtual_machine_scale_set.id
  type        = "Microsoft.Compute/virtualMachineScaleSets@2025-04-01"
  body = merge(
    # Zones update
    var.zones != null && length(var.zones) > 0 ? {
      zones = sort(tolist(var.zones))
    } : {}
    # Add more property updates here as needed using additional merge() blocks
  )
  read_headers   = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  update_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

  depends_on = [
    azapi_resource.virtual_machine_scale_set,
  ]

  # Trigger update when update_tracker is replaced
  lifecycle {
    ignore_changes = [
      body,
    ]
    replace_triggered_by = [
      terraform_data.update_tracker
    ]
  }
}

# AVM Required Code

moved {
  from = azurerm_management_lock.this
  to   = azapi_resource.lock
}

resource "azapi_resource" "lock" {
  count = var.lock != null ? 1 : 0

  name           = module.avm_utl_interfaces.lock_azapi.name != null ? module.avm_utl_interfaces.lock_azapi.name : "lock-${azapi_resource.virtual_machine_scale_set.name}"
  parent_id      = azapi_resource.virtual_machine_scale_set.id
  type           = module.avm_utl_interfaces.lock_azapi.type
  body           = module.avm_utl_interfaces.lock_azapi.body
  create_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers   = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  update_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

  depends_on = [azapi_resource.role_assignments]
}

moved {
  from = azurerm_role_assignment.this
  to   = azapi_resource.role_assignments
}

resource "azapi_resource" "role_assignments" {
  for_each = var.role_assignments

  name      = module.avm_utl_interfaces.role_assignments_azapi[each.key].name
  parent_id = azapi_resource.virtual_machine_scale_set.id
  type      = module.avm_utl_interfaces.role_assignments_azapi[each.key].type
  body = {
    properties = {
      principalId                        = module.avm_utl_interfaces.role_assignments_azapi[each.key].body.properties.principalId
      roleDefinitionId                   = module.avm_utl_interfaces.role_assignments_azapi[each.key].body.properties.roleDefinitionId
      condition                          = module.avm_utl_interfaces.role_assignments_azapi[each.key].body.properties.condition
      conditionVersion                   = module.avm_utl_interfaces.role_assignments_azapi[each.key].body.properties.conditionVersion
      delegatedManagedIdentityResourceId = module.avm_utl_interfaces.role_assignments_azapi[each.key].body.properties.delegatedManagedIdentityResourceId
      description                        = module.avm_utl_interfaces.role_assignments_azapi[each.key].body.properties.description == null ? "" : module.avm_utl_interfaces.role_assignments_azapi[each.key].body.properties.description
      principalType                      = coalesce(module.avm_utl_interfaces.role_assignments_azapi[each.key].body.properties.principalType, "User")
    }
  }
  create_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers   = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  retry = {
    error_message_regex = [
      ".*Please remove the lock and try again.*",
    ]
  }
  update_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
}
