variable "aws_region" {
  description = "AWS region for the state bucket"
  type        = string
  default     = "ap-southeast-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state (e.g. dhl-tf-state-<your-account-id>)"
  type        = string
}

variable "project" {
  description = "Project tag applied to bootstrap resources"
  type        = string
  default     = "dhl"
}
