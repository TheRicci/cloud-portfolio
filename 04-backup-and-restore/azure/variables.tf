variable "location" {
  description = "Azure region (e.g. eastus, westeurope)."
  type        = string
  default     = "eastus"
}

variable "admin_ssh_public_key" {
  description = "OpenSSH public key for the VM admin user."
  type        = string

  validation {
    condition     = startswith(var.admin_ssh_public_key, "ssh-")
    error_message = "Must be a valid OpenSSH public key starting with ssh-."
  }
}

variable "vm_size" {
  description = "VM size. Standard_B2ats_v2 has 2 vCPUs and 1 GiB RAM."
  type        = string
  default     = "Standard_B2ats_v2"
}

variable "name_prefix" {
  description = "Short prefix for resource names."
  type        = string
  default     = "backup-lab"
}

variable "alert_email" {
  description = "Email address for the budget alert."
  type        = string
}
