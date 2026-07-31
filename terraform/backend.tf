# Remote state backend. Backend blocks cannot use variables or interpolation,
# so these values are literal.
#
# Locking uses S3 native locking (use_lockfile, GA since Terraform 1.11) via
# a conditional-write lock file inside the state bucket itself - no DynamoDB
# table needed. The dhl-tf-locks DynamoDB table created earlier during setup
# is now unused; it's harmless (PAY_PER_REQUEST, empty, no cost) and can be
# deleted whenever convenient, or left alone.
terraform {
  backend "s3" {
    bucket       = "dhl-tf-state-460172970311"
    key          = "jenkins/terraform.tfstate"
    region       = "ap-southeast-1"
    use_lockfile = true
    encrypt      = true
  }
}
