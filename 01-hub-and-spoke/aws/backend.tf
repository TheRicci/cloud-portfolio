terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project     = "cloud-portfolio"
      sub-project = "01-hub-and-spoke"
      managed-by  = "terraform"
      session     = "aws-01"
    }
  }
}
