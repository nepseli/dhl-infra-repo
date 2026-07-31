output "jenkins_public_ip" {
  description = "Stable Elastic IP address for the Jenkins controller"
  value       = aws_eip.jenkins.public_ip
}

output "jenkins_url" {
  description = "Jenkins UI URL (stable across restarts/replacements)"
  value       = "http://${aws_eip.jenkins.public_ip}:8080"
}

output "jenkins_instance_id" {
  description = "EC2 instance id - use with 'aws ssm start-session --target <id>' for shell access"
  value       = aws_instance.jenkins.id
}

output "ssm_connect_command" {
  description = "Copy/paste command to open a shell on the instance via SSM Session Manager (no SSH key needed)"
  value       = "aws ssm start-session --target ${aws_instance.jenkins.id} --region ${var.aws_region}"
}
