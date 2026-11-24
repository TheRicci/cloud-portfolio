variable "location" {
  description = "Azure region for the state resource group and storage account."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that owns only portfolio Terraform state."
  type        = string
}

variable "storage_account_name" {
  description = "Globally unique 3-24 character Azure Storage account name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name must contain 3-24 lowercase letters or digits."
  }
}
