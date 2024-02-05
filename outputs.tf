output "resource" {
  description = "All attributes of the Virtual Machine Scale Set resource."
  sensitive   = true
  value       = azurerm_orchestrated_virtual_machine_scale_set.virtual_machine_scale_set
}

output "resource_id" {
  description = "The ID of the Virtual Machine Scale Set."
  value       = azurerm_orchestrated_virtual_machine_scale_set.virtual_machine_scale_set.id
}

output "resource_name" {
  description = "The name of the Virtual Machine Scale Set."
  value       = azurerm_orchestrated_virtual_machine_scale_set.virtual_machine_scale_set.name
}
