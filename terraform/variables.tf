variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-southeast-1"
}

variable "subnet_id" {
  description = "Subnet to launch the Jenkins instance into"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the Jenkins controller"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Existing EC2 key pair name. Fallback access only - primary access is via SSM Session Manager."
  type        = string
  default     = "prashanth-dhl-proj-key"
}

variable "admin_cidr" {
  description = "CIDR block allowed to reach the Jenkins UI on port 8080 (e.g. \"203.0.113.4/32\")"
  type        = string
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB - must be >= the latest AL2023 AMI's snapshot size (AWS periodically increases this; bump here if a future apply reports it's too small again)"
  type        = number
  default     = 30
}

variable "jenkins_data_volume_size" {
  description = "Size in GB of the dedicated EBS volume mounted at /var/lib/jenkins"
  type        = number
  default     = 20
}

variable "project" {
  description = "Project tag applied to all resources"
  type        = string
  default     = "dhl"
}

variable "environment" {
  description = "Environment tag applied to all resources"
  type        = string
  default     = "dev"
}

variable "tf_state_bucket" {
  description = "Name of the S3 bucket used for Terraform state (must match backend.tf)"
  type        = string
}

variable "enable_schedule" {
  description = "Whether to attach the automatic stop/start schedule to the instance"
  type        = bool
  default     = true
}

variable "schedule_stop_cron" {
  description = "EventBridge cron expression (UTC) for stopping the instance"
  type        = string
  default     = "cron(0 12 * * ? *)" # 20:00 SGT / 12:00 UTC
}

variable "schedule_start_cron" {
  description = "EventBridge cron expression (UTC) for starting the instance"
  type        = string
  default     = "cron(0 1 * * ? *)" # 09:00 SGT / 01:00 UTC
}

variable "budget_monthly_limit_usd" {
  description = "Monthly AWS Budgets alert threshold in USD"
  type        = number
  default     = 40
}

variable "budget_alert_email" {
  description = "Email address for AWS Budgets threshold alerts"
  type        = string
  default     = "neps.eli@gmail.com"
}
