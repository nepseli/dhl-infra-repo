resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Allow Jenkins UI access; shell access is via SSM Session Manager, not SSH"

  # No inbound rule for port 22: shell access goes through SSM Session
  # Manager (see iam.tf's AmazonSSMManagedInstanceCore attachment), so there
  # is no open SSH port or .pem key exposure at all.

  ingress {
    description = "Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}
