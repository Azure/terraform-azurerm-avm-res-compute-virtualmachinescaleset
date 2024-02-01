output "location" {
  value       = azurerm_resource_group.this.location
  description = "The deployment region."
}

output "resource_group_name" {
  value       = azurerm_resource_group.this.name
  description = "The name of the Resource Group."
}

output "virtual_machine_scale_set_id" {
  value       = module.terraform_azurerm_avm_res_compute_virtualmachinescaleset.resource_id
  description = "The ID of the Virtual Machine Scale Set."
}

output "virtual_machine_scale_set_name" {
  value       = module.terraform_azurerm_avm_res_compute_virtualmachinescaleset.resource_name
  description = "The name of the Virtual Machine Scale Set."
}

output "virtual_machine_scale_set" {
  value       = module.terraform_azurerm_avm_res_compute_virtualmachinescaleset.resource
  sensitive   = true
  description = "All attributes of the Virtual Machine Scale Set resource."
}