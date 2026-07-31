terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # v6 confirmed compatible: no OpsWorks/Batch/Redshift/CFN-StackSet
      # resources here, and aws_eip already uses domain="vpc" not the
      # removed vpc=true boolean.
    }
  }
}

provider "aws" {
  region = var.aws_region
}
