output "deployment_region" {
  description = "The selected region for deployment"
  value       = var.deployment_region
}

output "resource_id" {
  description = "Dummy variable to meet linting requirements"
  value       = ""
}

output "valid_skus" {
  description = "sku"
  value       = local.deploy_skus[*].name
}
