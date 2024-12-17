terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = ">= 1.15, < 3.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.116.0, < 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.2"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.6"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azapi" {
  use_msi = false
}
