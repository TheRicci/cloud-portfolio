terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# The subscription ID comes from the ARM_SUBSCRIPTION_ID environment variable.
provider "azurerm" {
  features {}
}
