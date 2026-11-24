variable "github_subject_plan" {
  description = "Exact, observed GitHub OIDC sub for the azure-plan environment."
  type        = string

  validation {
    condition     = startswith(var.github_subject_plan, "repo:") && !strcontains(var.github_subject_plan, "*")
    error_message = "github_subject_plan must be an exact GitHub OIDC subject without a wildcard."
  }
}

variable "github_subject_apply" {
  description = "Exact, observed GitHub OIDC sub for the azure-apply environment."
  type        = string

  validation {
    condition     = startswith(var.github_subject_apply, "repo:") && !strcontains(var.github_subject_apply, "*")
    error_message = "github_subject_apply must be an exact GitHub OIDC subject without a wildcard."
  }
}

variable "deployment_resource_group_id" {
  description = "Resource ID of the pre-created group that future portfolio projects may deploy into."
  type        = string
}

variable "state_resource_group_name" {
  description = "Name of the Azure state resource group created by bootstrap."
  type        = string
}

variable "state_storage_account_name" {
  description = "Name of the Azure Storage account created by bootstrap."
  type        = string
}

variable "state_container_name" {
  description = "Private state container name created by bootstrap."
  type        = string
  default     = "tfstate"
}
