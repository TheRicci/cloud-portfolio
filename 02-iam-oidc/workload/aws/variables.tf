variable "region" {
  description = "AWS region for the showcase workload VM."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment tag."
  type        = string
  default     = "portfolio-demo"
}
