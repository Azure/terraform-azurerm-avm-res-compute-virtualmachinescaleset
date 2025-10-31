module "managed_identities" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.5.0"

  enable_telemetry   = var.enable_telemetry
  managed_identities = var.managed_identities
}