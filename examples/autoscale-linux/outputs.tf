output "location" {
  description = "The deployment region."
  value       = azurerm_resource_group.this.location
}

output "password_key_vault_secret_id" {
  description = "The ID of the Key Vault secret storing the VM admin password."
  value       = module.avm-ptn-ephemeral-credential.retrievable_secret_id
}

output "resource_group_name" {
  description = "The name of the Resource Group."
  value       = azurerm_resource_group.this.name
}

output "resource_id" {
  description = "The ID of the Virtual Machine Scale Set"
  value       = module.terraform_azurerm_avm_res_compute_virtualmachinescaleset.resource_id
}

output "virtual_machine_scale_set_id" {
  description = "The ID of the Virtual Machine Scale Set."
  value       = module.terraform_azurerm_avm_res_compute_virtualmachinescaleset.resource_id
}

output "virtual_machine_scale_set_name" {
  description = "The name of the Virtual Machine Scale Set."
  value       = module.terraform_azurerm_avm_res_compute_virtualmachinescaleset.resource_name
}
