locals {
  admin_password_linux = (try(var.os_profile.linux_configuration, {}) != {}) ? (
    var.os_profile.linux_configuration.disable_password_authentication == false ? (                          #if os is linux and password authentication is enabled
      var.generate_admin_password_or_ssh_key ? random_password.admin_password[0].result : var.admin_password #use generated password, password variable
    ) : null
  ) : null
  #set the admin password to either a generated value or the entered value
  admin_password_windows = (try(var.os_profile.windows_configuration, {}) != {}) ? (
    var.generate_admin_password_or_ssh_key ? random_password.admin_password[0].result : var.admin_password #use generated password, password variable
  ) : null
  #format the admin ssh key so it can be concat'ed to the other keys.
  admin_ssh_key = (((var.generate_admin_password_or_ssh_key == true) && (try(var.os_profile.linux_configuration, {}) != {})) ?
    [{
      public_key = tls_private_key.this[0].public_key_openssh
      username   = var.os_profile.linux_configuration.admin_username
    }] :
  [])
  #concat the ssh key values list 
  admin_ssh_keys                       = concat(var.admin_ssh_keys, local.admin_ssh_key)
  generated_secret_expiration_date_utc = var.generated_secrets_key_vault_secret_config != null ? formatdate("YYYY-MM-DD'T'hh:mm:ssZ", (timeadd(timestamp(), "${var.generated_secrets_key_vault_secret_config.expiration_date_length_in_days * 24}h"))) : null
  role_definition_resource_substring   = "providers/Microsoft.Authorization/roleDefinitions"
}

# Helper locals to make the dynamic block more readable
locals {
  managed_identities = {
    user_assigned = length(var.managed_identities.user_assigned_resource_ids) > 0 ? {
      this = {
        type                       = "UserAssigned"
        user_assigned_resource_ids = var.managed_identities.user_assigned_resource_ids
      }
    } : {}
  }
}