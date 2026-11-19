variable "location" {
  description = "Azure region for deployment (e.g. eastus, westeurope)."
  type        = string
}

variable "admin_ssh_public_key" {
  description = "OpenSSH public key for the VM admin user."
  type        = string

  validation {
    condition     = startswith(var.admin_ssh_public_key, "ssh-")
    error_message = "admin_ssh_public_key must be a valid OpenSSH public key starting with ssh-."
  }
}

variable "vm_size" {
  description = "Virtual machine size (Standard_B2s provides 2 vCPUs and 4 GiB RAM)."
  type        = string
  default     = "Standard_B2s"
}

variable "alert_email" {
  description = "Email address for the Azure Monitor CPU alert Action Group."
  type        = string
}

variable "name_prefix" {
  description = "Short prefix for Azure resource naming."
  type        = string
  default     = "portfolio-observability"
}

variable "smtp_smarthost" {
  description = "SMTP host:port for Alertmanager email delivery (optional)."
  type        = string
  default     = "localhost:25"
}

variable "smtp_username" {
  description = "SMTP username for Alertmanager (optional)."
  type        = string
  default     = "none"
}

variable "smtp_password" {
  description = "SMTP password for Alertmanager (optional)."
  type        = string
  sensitive   = true
  default     = "none"
}

variable "smtp_from" {
  description = "Sender email address for Alertmanager (optional)."
  type        = string
  default     = "alerts@example.com"
}

variable "grafana_admin_password" {
  description = "Admin password for the Grafana UI."
  type        = string
  sensitive   = true
  default     = "admin"
}
