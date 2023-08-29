variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see https://aka.ms/avm/telemetry.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
}

variable "resource_group_name" {
  type        = string
  description = "The resource group where the resources will be deployed."
}

variable "location" {
  type        = string
  description = "The Azure location where the resources will be deployed."
}

variable "tags" {
  type        = map(any)
  description = "A map of tags to add to the VM scale set."
}

variable "name" {
  type        = string
  description = "The name of the VM scale set."
}

variable "os_type" {
  type        = string
  description = "The type of operating system, either `linux` or `windows`."
  validation {
    condition     = can(regex("^linux$|^windows$", var.os_type))
    error_message = "The os_type variable must be either linux or windows."
  }

  variable "sku" {
    type        = string
    description = "The VM SKU to use for the VM scale set, e.g. `Standard_F2`."
  }

  variable "instances" {
    type        = number
    description = "The number of instances to create in the VM scale set."
  }

  variable "admin_password" {
    type        = string
    description = "The admin password for the VM scale set. Conflicts with admin_ssh_key."
    sensitive   = true
    default     = null
  }
}
