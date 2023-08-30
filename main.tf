resource "azurerm_linux_virtual_machine_scale_set" {
  for_each            = var.os_type == "linux" ? toset(["this"]) : toset([])
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  admin_username      = var.admin_username
  sku                 = var.sku
  instances           = var.instances
  network_interface {

  }
}

# resource "azurerm_windows_virtual_machine_scale_set" {
#   for_each            = var.os_type == "windows" ? toset(["this"]) : toset([])
#   name                = var.name
#   resource_group_name = var.resource_group_name
#   location            = var.location
#   admin_username      = var.admin_username
#   sku                 = var.sku
#   instances           = var.instances
# }
