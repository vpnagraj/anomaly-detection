## ==================== PROVIDER CONFIGURATION ====================
## configures the AWS provider for Terraform
## Terraform needs to know which cloud provider (and region) to use

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  ## set the region via variable (defaults to us-east-1)
  region = var.aws_region
}
