variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "brazilsouth"
}

variable "prefix" {
  description = "Short prefix used in all resource names to avoid collisions."
  type        = string
  default     = "portfolio-hs"
}

variable "hub_address_space" {
  description = "CIDR block for the hub VNet. Must match cidr-plan.yaml."
  type        = string
  default     = "10.0.0.0/16"
}

variable "spoke1_address_space" {
  description = "CIDR block for Spoke 1 VNet. Must match cidr-plan.yaml."
  type        = string
  default     = "10.1.0.0/16"
}

variable "spoke2_address_space" {
  description = "CIDR block for Spoke 2 VNet. Must match cidr-plan.yaml."
  type        = string
  default     = "10.2.0.0/16"
}

variable "hub_subnet_prefix" {
  type    = string
  default = "10.0.1.0/24"
}

variable "spoke1_subnet_prefix" {
  type    = string
  default = "10.1.1.0/24"
}

variable "spoke2_subnet_prefix" {
  type    = string
  default = "10.2.1.0/24"
}

variable "vm_size" {
  description = "VM size for NVA and spoke test VMs. B1s is free-tier eligible."
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Local admin username for all VMs."
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "SSH public key for the VM administrator. Supply it with TF_VAR_admin_ssh_public_key or a tfvars file kept out of version control."
  type        = string
}
