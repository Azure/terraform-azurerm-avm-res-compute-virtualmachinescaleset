locals {
  role_definition_resource_substring = "providers/Microsoft.Authorization/roleDefinitions"
}

# Helper locals to make the dynamic block more readable
locals {
  managed_identities = module.managed_identities.managed_identities_azapi
}

# SSH key lookup map for Linux configuration
locals {
  ssh_keys_map = var.admin_ssh_keys != null ? {
    for key in var.admin_ssh_keys : key.id => key
  } : {}
}

# Computer name prefix default and validation
locals {
  computer_name_prefix_valid = local.windows_prefix_valid && local.linux_prefix_valid
  default_computer_name_prefix = coalesce(
    try(var.os_profile.linux_configuration.computer_name_prefix, null),
    try(var.os_profile.windows_configuration.computer_name_prefix, null),
    var.name
  )
  is_linux = var.os_profile != null && var.os_profile.linux_configuration != null
  # Determine if this is a Windows or Linux configuration
  is_windows = var.os_profile != null && var.os_profile.windows_configuration != null
  # Linux computer name prefix validation (max 58 chars, no special chars, no leading underscore, no trailing period)
  linux_prefix_valid = local.is_linux ? (
    length(local.default_computer_name_prefix) <= 58 &&
    !can(regex("^_", local.default_computer_name_prefix)) &&
    !can(regex("[.]$", local.default_computer_name_prefix)) &&
    !can(regex("[\\\\\"\\[\\]:|<>+=;,?*@&~!#$%^()_{}']", local.default_computer_name_prefix))
  ) : true
  # Windows computer name prefix validation (max 9 chars, alphanumeric and hyphens, cannot be only numbers)
  windows_prefix_valid = local.is_windows ? (
    length(local.default_computer_name_prefix) <= 9 &&
    can(regex("^[a-zA-Z0-9-]+$", local.default_computer_name_prefix)) &&
    !can(regex("^[0-9]+$", local.default_computer_name_prefix))
  ) : true
}

# Zones drift detection
# Detects when zones are removed from configuration, which requires resource recreation
# This mimics the azurerm provider behavior that prevents zone removal
locals {
  # Get desired zones from configuration (empty list if not specified)
  desired_zones = var.zones != null ? tolist(var.zones) : []
  # Get existing zones from the deployed resource (empty list if resource doesn't exist)
  existing_zones = data.azapi_resource.existing_vmss.exists ? try(
    data.azapi_resource.existing_vmss.output.zones,
    []
  ) : []
  # Replacement trigger: changes when zones are removed to force resource recreation
  # This ensures the resource is recreated when zones are removed, matching azurerm provider behavior
  # Use a hash of the removed zones to create a stable trigger that only changes when zones are actually removed
  removed_zones_list = [
    for zone in local.existing_zones : zone
    if !contains(local.desired_zones, zone)
  ]
  # Check if any existing zone has been removed
  # Returns true if any zone that exists in Azure is missing from the desired configuration
  zones_removed = length(local.existing_zones) > 0 && length([
    for zone in local.existing_zones : zone
    if !contains(local.desired_zones, zone)
  ]) > 0
  zones_replacement_trigger = local.zones_removed ? sha256(jsonencode(sort(local.removed_zones_list))) : null
}

# Single placement group change detection
# Detects when single_placement_group is being changed from false to true
# This change is not allowed by Azure and requires resource recreation
locals {
  # Get existing single_placement_group value from the deployed resource
  existing_single_placement_group = data.azapi_resource.existing_vmss.exists ? try(
    data.azapi_resource.existing_vmss.output.properties.singlePlacementGroup,
    false
  ) : false
  # Detect if attempting to change from false to true (not allowed, requires recreation)
  single_placement_group_invalid_change = (
    data.azapi_resource.existing_vmss.exists &&
    local.existing_single_placement_group == false &&
    var.single_placement_group == true
  )
  # Replacement trigger: forces recreation when attempting invalid change
  # Use a hash of the state to create a stable trigger that only changes when the invalid change is detected
  # This prevents infinite loops by ensuring the hash stays consistent after recreation
  single_placement_group_trigger = local.single_placement_group_invalid_change ? sha256(jsonencode({
    existing = local.existing_single_placement_group
    desired  = var.single_placement_group
  })) : null
}

# License type normalization
# The azurerm provider converts empty string to "None" during updates
# This mimics that behavior to prevent drift
locals {
  # Normalize license_type: convert empty string to "None" during updates to match azurerm provider behavior
  # The Azure API doesn't accept empty string for license_type during updates
  # Only apply this conversion when updating an existing VMSS
  normalized_license_type = (
    data.azapi_resource.existing_vmss.exists && var.license_type == "" ? "None" : var.license_type
  )
}

# Health extension detection
# Detects if any configured extension is an application health extension
# This mimics the azurerm provider's hasHealthExtension logic used for validation
locals {
  # Check if any extension is an application health extension
  # Application health extensions are: ApplicationHealthLinux or ApplicationHealthWindows
  # Note: Only the type is checked, not the publisher (matches azurerm provider behavior)
  has_health_extension = try(anytrue([
    for ext in var.extension :
    ext.type == "ApplicationHealthLinux" ||
    ext.type == "ApplicationHealthWindows"
  ]), false)
}

# Hotpatch-enabled image detection
# Detects if the source image reference is a Windows Server hotpatch-enabled SKU
# This mimics the azurerm provider's isValidHotPatchSourceImageReference logic
locals {
  # Hotpatch is only supported for specific Windows Server SKUs from Microsoft
  # When using source_image_id (custom images), hotpatching is not supported
  is_hotpatch_enabled_image = (
    var.source_image_id == null &&
    var.source_image_reference != null &&
    var.source_image_reference.publisher == "MicrosoftWindowsServer" &&
    var.source_image_reference.offer == "WindowsServer" &&
    contains([
      "2022-datacenter-azure-edition-core",
      "2022-datacenter-azure-edition-core-smalldisk",
      "2022-datacenter-azure-edition-hotpatch",
      "2022-datacenter-azure-edition-hotpatch-smalldisk",
      "2025-datacenter-azure-edition",
      "2025-datacenter-azure-edition-smalldisk",
      "2025-datacenter-azure-edition-core",
      "2025-datacenter-azure-edition-core-smalldisk"
    ], var.source_image_reference.sku)
  )
}
