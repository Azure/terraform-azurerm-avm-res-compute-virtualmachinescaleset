variable "deployment_region" {
  type        = string
  description = "The selected region for deployment"
}

variable "hibernation_supported" {
  type        = bool
  default     = false
  description = "When true, only return sizes that advertise the `HibernationSupported` capability. Hibernation is limited to a subset of the v5 D and E families, so leave this false unless the example enables hibernation."
  nullable    = false
}
