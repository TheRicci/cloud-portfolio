variable "region" {
  description = "Region allowed for the AWS apply role's portfolio resources."
  type        = string
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket created by bootstrap."
  type        = string
}

variable "state_key" {
  description = "Exact object key for this root's remote state."
  type        = string
  default     = "02-iam-oidc/aws/terraform.tfstate"
}

variable "github_subject_plan" {
  description = "Exact, observed GitHub OIDC sub for the aws-plan environment."
  type        = string

  validation {
    condition     = startswith(var.github_subject_plan, "repo:") && !strcontains(var.github_subject_plan, "*")
    error_message = "github_subject_plan must be an exact GitHub OIDC subject without a wildcard."
  }
}

variable "github_subject_apply" {
  description = "Exact, observed GitHub OIDC sub for the aws-apply environment."
  type        = string

  validation {
    condition     = startswith(var.github_subject_apply, "repo:") && !strcontains(var.github_subject_apply, "*")
    error_message = "github_subject_apply must be an exact GitHub OIDC subject without a wildcard."
  }
}
