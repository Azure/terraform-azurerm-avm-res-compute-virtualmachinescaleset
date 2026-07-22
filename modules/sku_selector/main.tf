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
  #preferred skus: the strict capability set (Gen1+Gen2 support, 2 cpu, encryption at host, x64, premium io).
  #kept as the first choice so previously selected skus are still used wherever they exist.
  preferred_skus = [
    for sku in local.location_valid_vms : sku
    if length([
      for capability in sku.capabilities : capability
      if(capability.name == "HyperVGenerations" && capability.value == "V1,V2") ||
      (capability.name == "vCPUs" && capability.value == "2") ||
      (capability.name == "EncryptionAtHostSupported" && capability.value == "True") ||
      (capability.name == "CpuArchitectureType" && capability.value == "x64") ||
      (capability.name == "PremiumIO" && capability.value == "True")
    ]) == 5
  ]
  #fallback skus: broaden the strict set by dropping ONLY the encryption-at-host requirement (no example
  #enables encryption at host). still require Gen1+Gen2 support (V1,V2) so the selected sku boots the Windows
  #examples' Gen1 image and is SCSI-bootable - this also excludes Gen2-only / NVMe-only families (e.g. L-series).
  #2 cpu, x64 and premium io remain required (the module's default os disk is Premium_LRS).
  fallback_skus = [
    for sku in local.location_valid_vms : sku
    if length([
      for capability in sku.capabilities : capability
      if(capability.name == "HyperVGenerations" && capability.value == "V1,V2") ||
      (capability.name == "vCPUs" && capability.value == "2") ||
      (capability.name == "CpuArchitectureType" && capability.value == "x64") ||
      (capability.name == "PremiumIO" && capability.value == "True")
    ]) == 4
  ]
  #prefer the strict set, fall back to the relaxed set so a valid sku is found in virtually every region.
  #this prevents the flaky empty-list case where random_integer would get max < min.
  deploy_skus = length(local.preferred_skus) > 0 ? local.preferred_skus : local.fallback_skus
}

resource "random_integer" "deploy_sku" {
  max = max(length(local.deploy_skus) - 1, 0) #guard against an empty list (max must never be below min)
  min = 0
}