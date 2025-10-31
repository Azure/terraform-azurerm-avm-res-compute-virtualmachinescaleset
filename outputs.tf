output "resource_id" {
  description = "The ID of the Virtual Machine Scale Set."
  value       = azapi_resource.virtual_machine_scale_set.id
}

output "resource_name" {
  description = "The name of the Virtual Machine Scale Set."
  value       = var.name
}
