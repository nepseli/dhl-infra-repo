subnet_id  = "subnet-07223335b55360163"
admin_cidr = "118.200.15.21/32" # e.g. run `curl ifconfig.me` and append /32

# Must match the literal bucket name in backend.tf (backend blocks can't
# read variables).
tf_state_bucket = "dhl-tf-state-460172970311"

# These are safe to commit: nothing above is a secret, just environment
# config. See dhl-infra-improvement-plan.md for why this repo intentionally
# keeps terraform.tfvars tracked instead of gitignoring it.
