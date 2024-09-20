output "resource_id" {
  description = "Dummy variable to meet linting requirements"
  value       = ""
}

output "sku" {
  description = "sku"
  value       = try(local.deploy_skus[random_integer.deploy_sku.result].name, "no_current_valid_skus")
}
