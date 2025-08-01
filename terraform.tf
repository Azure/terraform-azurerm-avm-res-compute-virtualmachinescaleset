terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.26, != 4.37.0, != 4.38.0, != 4.38.1"
      # version 4.37.0 introduced a new variable network_api_version causes inconsistent final plan error, this is probably due to a bug in azurerm go code DiffSuppressFunc for network_api_version. 
    }
    modtm = {
      source  = "Azure/modtm"
      version = "~> 0.3"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.2"
    }
  }
}
