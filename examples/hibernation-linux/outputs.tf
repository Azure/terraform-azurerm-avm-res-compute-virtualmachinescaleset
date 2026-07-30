output "hibernation_enabled" {
  description = "The `hibernationEnabled` capability as reported by Azure for the deployed Virtual Machine Scale Set."
  value       = try(data.azapi_resource.hibernation_readback.output.properties.additionalCapabilities.hibernationEnabled, null)
}

output "location" {
  description = "The deployment region."
  value       = azurerm_resource_group.this.location
}

output "resource_group_name" {
  description = "The name of the Resource Group."
  value       = azurerm_resource_group.this.name
}

output "resource_id" {
  description = "The ID of the Virtual Machine Scale Set"
  value       = module.terraform_azurerm_avm_res_compute_virtualmachinescaleset.resource_id
}

output "sku_name" {
  description = "The hibernation capable VM size selected for the deployment region."
  value       = module.get_valid_sku_for_deployment_region.sku
}

output "virtual_machine_scale_set_name" {
  description = "The name of the Virtual Machine Scale Set."
  value       = module.terraform_azurerm_avm_res_compute_virtualmachinescaleset.resource_name
}
