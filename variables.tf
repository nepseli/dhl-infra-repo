variable "instance_type" {
  default = "t2.medium"
}

variable "key_name" {
  description = "Your EC2 key pair name"
}

variable "jenkins_port" {
  default = 8080
}
