variable "resource_group_name" {
  description = "Pre-created deployment resource group managed by the apply identity."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment tag."
  type        = string
  default     = "portfolio-demo"
}
