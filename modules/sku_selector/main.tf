### this segment of code gets valid vm skus for deployment in the current subscription
data "azurerm_subscription" "current" {}

#get the full sku list (azapi doesn't currently have a good way to filter the api call)
data "azapi_resource_list" "example" {
  parent_id              = data.azurerm_subscription.current.id
  type                   = "Microsoft.Compute/skus?$filter=location%20eq%20%27${var.deployment_region}%27@2021-07-01"
  response_export_values = ["*"]
}

locals {
  #filter the location output for the current region, virtual machine resources, and filter out entries that don't include the capabilities list
  location_valid_vms = [
    for location in data.azapi_resource_list.example.output.value : location
    if length(location.restrictions) < 1 &&       #there are no restrictions on deploying the sku (i.e. allowed for deployment)
    location.resourceType == "virtualMachines" && #and the sku is a virtual machine
    !strcontains(location.name, "C") &&           #no confidential vm skus
    !strcontains(location.name, "B") &&           #no B skus
    length(try(location.capabilities, [])) > 1    #avoid skus where the capabilities list isn't defined
  ]
  #the linux examples force diskControllerType = "SCSI", so drop NVMe-only skus (they can't boot the SCSI controller).
  #skus without a DiskControllerTypes capability are older sizes that default to SCSI, so they are kept.
  scsi_bootable_vms = [
    for sku in local.location_valid_vms : sku
    if length([
      for capability in sku.capabilities : capability
      if capability.name == "DiskControllerTypes" && strcontains(capability.value, "NVMe") && !strcontains(capability.value, "SCSI")
    ]) == 0
  ]
  #eligible skus: Gen2 support (V2), x64, and premium io (the module's default os disk is Premium_LRS).
  #NVMe-only skus are already excluded above, so the selected sku is SCSI-bootable for the linux examples.
  eligible_skus = [
    for sku in local.scsi_bootable_vms : sku
    if length([
      for capability in sku.capabilities : capability
      if(capability.name == "HyperVGenerations" && strcontains(capability.value, "V2")) ||
      (capability.name == "CpuArchitectureType" && capability.value == "x64") ||
      (capability.name == "PremiumIO" && capability.value == "True")
    ]) == 3
  ]
  #prefer 2-vCPU sizes; only fall back to 4-vCPU sizes when the region has no 2-vCPU eligible sku.
  #this keeps the selected size small and avoids the flaky empty-list case for random_integer.
  skus_2vcpu  = [for sku in local.eligible_skus : sku if anytrue([for c in sku.capabilities : c.name == "vCPUs" && c.value == "2"])]
  skus_4vcpu  = [for sku in local.eligible_skus : sku if anytrue([for c in sku.capabilities : c.name == "vCPUs" && c.value == "4"])]
  deploy_skus = length(local.skus_2vcpu) > 0 ? local.skus_2vcpu : local.skus_4vcpu
}

resource "random_integer" "deploy_sku" {
  max = max(length(local.deploy_skus) - 1, 0) #guard against an empty list (max must never be below min)
  min = 0

  lifecycle {
    #fail fast here (before the scale set is created) when nothing matched, instead of emitting the
    #"no_current_valid_skus" sentinel that only surfaces later as an opaque 400 InvalidParameter on the vmss PUT.
    precondition {
      condition     = length(local.deploy_skus) > 0
      error_message = "sku_selector found no deployable VM size in region '${var.deployment_region}'. Candidate counts by stage - location_valid_vms: ${length(local.location_valid_vms)}, scsi_bootable_vms: ${length(local.scsi_bootable_vms)}, eligible_skus: ${length(local.eligible_skus)}, 2-vCPU: ${length(local.skus_2vcpu)}, 4-vCPU: ${length(local.skus_4vcpu)}. Required capabilities: Gen2 (V2), 2 or 4 vCPUs, x64, PremiumIO, SCSI-boot. Pick another region or relax the sku_selector filters."
    }
  }
}