variable "region" {
  description = "AWS region. Use the same region every session."
  type        = string
}

variable "session_id" {
  description = "Short ID for this session. Used in tags and names."
  type        = string
}

variable "allowed_cidr" {
  description = "Your public IP as a /32. Only this address can reach SSH and the decoy port."
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_cidr, 0)) && endswith(var.allowed_cidr, "/32")
    error_message = "allowed_cidr must be a single address in /32 form, for example 203.0.113.7/32."
  }
}

variable "ssh_public_key" {
  description = "Contents of your SSH public key. Never put a private key here."
  type        = string
}

variable "repo_url" {
  description = "Public HTTPS clone URL of the portfolio repository."
  type        = string
}

variable "repo_sha" {
  description = "Full 40-character commit SHA the VM pulls."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{40}$", var.repo_sha))
    error_message = "repo_sha must be a full 40-character lowercase commit SHA."
  }
}

variable "project_dir" {
  description = "Folder of this project inside the repository."
  type        = string
  default     = "hardening-drift"
}

variable "pull_interval_min" {
  description = "Minutes between scheduled playbook runs."
  type        = number
  default     = 3
}

variable "weak_baseline" {
  description = "Start from a deliberately weak SSH config so there is something to harden."
  type        = bool
  default     = true
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "ansible_bundle_b64" {
  description = "Optional base64-encoded tar.gz of ansible/ for local runs without pushing."
  type        = string
  default     = ""
}
