# Pins the AZ to the subnet's fixed AZ rather than the instance's computed
# attribute, so aws_ebs_volume.jenkins_data below doesn't get forced to
# replace (and lose JENKINS_HOME) every time aws_instance.jenkins does.
data "aws_subnet" "selected" {
  id = var.subnet_id
}

resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.jenkins.name

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user-data.sh.tpl", {
    plugins_txt = file("${path.module}/plugins.txt")
  })
  # EC2 only executes user_data on an instance's first boot - without this,
  # editing user-data.sh.tpl and re-applying would silently do nothing to
  # an already-running instance. This makes a user_data change force a
  # clean replacement instead, matching how it's easy to assume it works.
  user_data_replace_on_change = true

  tags = {
    Name        = "jenkins-server"
    Project     = var.project
    Environment = var.environment
  }
}

# Dedicated volume for JENKINS_HOME so its size/persistence is decoupled
# from instance RAM (see ADR-0001 - the /tmp-tmpfs disk-space alarm was a
# symptom of everything living on a small, RAM-adjacent instance).
resource "aws_ebs_volume" "jenkins_data" {
  availability_zone = data.aws_subnet.selected.availability_zone
  size              = var.jenkins_data_volume_size
  type              = "gp3"

  tags = {
    Name        = "jenkins-data"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_volume_attachment" "jenkins_data" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.jenkins_data.id
  instance_id = aws_instance.jenkins.id
}

resource "aws_eip" "jenkins" {
  instance = aws_instance.jenkins.id
  domain   = "vpc"

  tags = {
    Name        = "jenkins-eip"
    Project     = var.project
    Environment = var.environment
  }
}
