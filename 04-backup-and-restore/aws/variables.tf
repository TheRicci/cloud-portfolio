variable "region" {
  description = "AWS region for the session."
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type. t3.micro has 1 GiB RAM and 2 vCPUs."
  type        = string
  default     = "t3.micro"
}

variable "name_prefix" {
  description = "Short prefix for resource names. Keep it unique in the account."
  type        = string
  default     = "backup-lab"
}

variable "alert_email" {
  description = "Email address for the budget alert."
  type        = string
}
