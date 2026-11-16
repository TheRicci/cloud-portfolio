variable "region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "prefix" {
  description = "Short prefix for resource names."
  type        = string
  default     = "portfolio-hs"
}

variable "hub_cidr" {
  description = "CIDR for hub VPC. Must match cidr-plan.yaml."
  type        = string
  default     = "10.10.0.0/16"
}

variable "spoke1_cidr" {
  description = "CIDR for Spoke 1 VPC. Must match cidr-plan.yaml."
  type        = string
  default     = "10.11.0.0/16"
}

variable "spoke2_cidr" {
  description = "CIDR for Spoke 2 VPC. Must match cidr-plan.yaml."
  type        = string
  default     = "10.12.0.0/16"
}

variable "hub_tgw_subnet_cidr" {
  type    = string
  default = "10.10.1.0/24"
}

variable "hub_nva_subnet_cidr" {
  type    = string
  default = "10.10.2.0/24"
}

variable "spoke1_subnet_cidr" {
  type    = string
  default = "10.11.1.0/24"
}

variable "spoke2_subnet_cidr" {
  type    = string
  default = "10.12.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type for spoke test VMs."
  type        = string
  default     = "t3.micro"
}
