variable "region" {
  description = "AWS region for this short-lived session."
  type        = string
}

variable "instance_type" {
  description = "Two GiB class instance type."
  type        = string
  default     = "t3.small"
}



variable "alert_email" {
  description = "Email endpoint for the SNS CPU alarm. Confirm the subscription email after apply."
  type        = string
}

variable "name_prefix" {
  description = "Short name prefix; keep it unique in the account and region."
  type        = string
  default     = "portfolio-observability"
}

variable "smtp_username" {
  description = "AWS SES SMTP username (the AKIA... access key ID from SES → SMTP settings → Create SMTP credentials)."
  type        = string
}

variable "smtp_password" {
  description = "AWS SES SMTP password (the derived secret shown once at SMTP credential creation — not the IAM secret key)."
  type        = string
  sensitive   = true
}

variable "smtp_from" {
  description = "Verified SES sender email address used as the From: address on all alert emails."
  type        = string
}

variable "grafana_admin_password" {
  description = "Grafana web UI admin password. Avoid the two-character sequence $ { in the value."
  type        = string
  sensitive   = true
}

