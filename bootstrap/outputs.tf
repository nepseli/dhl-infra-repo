output "state_bucket" {
  description = "Copy this into terraform/backend.tf's bucket field and terraform/terraform.tfvars' tf_state_bucket"
  value       = aws_s3_bucket.tf_state.bucket
}
