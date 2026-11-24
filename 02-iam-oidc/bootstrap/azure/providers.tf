terraform {
  required_version = ">= 1.7"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}

  # The state account disables Shared Key authorization. Terraform must use the
  # bootstrap operator's Microsoft Entra token for blob data-plane operations.
  storage_use_azuread = true
}
