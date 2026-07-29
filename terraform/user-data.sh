#!/bin/bash
sudo yum update -y

# Install Java
sudo amazon-linux-extras install java-openjdk11 -y

# Install Jenkins
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
sudo yum install jenkins -y

sudo systemctl enable jenkins
sudo systemctl start jenkins
