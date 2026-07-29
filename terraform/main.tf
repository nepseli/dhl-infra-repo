resource "aws_instance" "jenkins" {
  ami                    = "ami-0171b4dad6e6f9dfe"
  instance_type          = "t3.micro"
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  key_name               = "prashanth-dhl-proj-key"
  user_data = file("${path.module}/user-data.sh")

  tags = {
    Name = "jenkins-server"
  }
}
