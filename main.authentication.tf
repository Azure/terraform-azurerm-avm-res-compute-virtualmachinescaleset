####Admin password related Resources
#generate the initial admin password if requested

#scenarios: 
#Linux, password auth disabled, gen ssh - false
#Linux, password auth enabled, gen ssh - true
#Linux, Password auth disabled, no gen ssh - false
#Linux, Password auth enabled, no gen ssh - false
#Windows, password auth disabled (no action), gen password - true
#Windows, password auth enabled (no action), gen password - true
#Windows, Password auth disabled (no action), no gen password - false
#Windows, password auth enabled (noaction), no gen password - false
resource "random_password" "admin_password" {
  count = (((var.os_profile.windows_configuration != null) && (var.generate_admin_password_or_ssh_key == true)) || (((var.generate_admin_password_or_ssh_key == true) && (var.os_profile.linux_configuration != null) && (try(var.os_profile.linux_configuration.disable_password_authentication, false) == false)))) ? 1 : 0

  length           = 22
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  min_upper        = 2
  override_special = "!#$%&()*+,-./:;<=>?@[]^_{|}~"
  special          = true
}

#store the initial password in the secrets key vault
#Requires that the deployment user has key vault secrets write access
resource "azurerm_key_vault_secret" "admin_password" {
  count = (((var.generate_admin_password_or_ssh_key == true) && (var.os_profile.windows_configuration != null) && (var.generated_secrets_key_vault_secret_config != null)) || ((var.generate_admin_password_or_ssh_key == true) && (var.os_profile.linux_configuration != null) && (try(var.os_profile.linux_configuration.disable_password_authentication, false) == false) && (var.generated_secrets_key_vault_secret_config != null))) ? 1 : 0

  key_vault_id    = var.generated_secrets_key_vault_secret_config.key_vault_resource_id
  name            = coalesce(var.generated_secrets_key_vault_secret_config.name, try("${var.name}-${var.os_profile.linux_configuration.admin_username}-password", "${var.name}-${var.os_profile.windows_configuration.admin_username}-password"))
  value           = random_password.admin_password[0].result
  content_type    = var.generated_secrets_key_vault_secret_config.content_type
  expiration_date = local.generated_secret_expiration_date_utc
  not_before_date = var.generated_secrets_key_vault_secret_config.not_before_date
  tags            = var.generated_secrets_key_vault_secret_config.tags != {} ? var.generated_secrets_key_vault_secret_config.tags : var.tags

  lifecycle {
    ignore_changes = [expiration_date]
  }
}

####Admin SSH key generation related resources
#create an ssh key for the admin user in linux
resource "tls_private_key" "this" {
  count = ((var.generate_admin_password_or_ssh_key == true) && (var.os_profile.linux_configuration != null) && (try(var.os_profile.linux_configuration.disable_password_authentication, false) == true)) ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 4096
}

#Store the created ssh key in the secrets key vault
resource "azurerm_key_vault_secret" "admin_ssh_key" {
  count = ((var.generate_admin_password_or_ssh_key == true) && (var.os_profile.linux_configuration != null) && (try(var.os_profile.linux_configuration.disable_password_authentication, false) == true) && (var.generated_secrets_key_vault_secret_config != null)) ? 1 : 0

  key_vault_id    = var.generated_secrets_key_vault_secret_config.key_vault_resource_id
  name            = coalesce(var.generated_secrets_key_vault_secret_config.name, try("${var.name}-${var.os_profile.linux_configuration.admin_username}-ssh-private-key", "${var.name}-${var.os_profile.windows_configuration.admin_username}-ssh-private-key"))
  value           = tls_private_key.this[0].private_key_pem
  content_type    = var.generated_secrets_key_vault_secret_config.content_type
  expiration_date = local.generated_secret_expiration_date_utc
  not_before_date = var.generated_secrets_key_vault_secret_config.not_before_date
  tags            = var.generated_secrets_key_vault_secret_config.tags != {} ? var.generated_secrets_key_vault_secret_config.tags : var.tags

  lifecycle {
    ignore_changes = [expiration_date]
  }
}
