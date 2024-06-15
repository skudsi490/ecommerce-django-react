terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

# Variables
variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "subnet1_cidr" {
  default = "10.0.1.0/24"
}

variable "subnet2_cidr" {
  default = "10.0.2.0/24"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "key_name" {
  description = "Name of the SSH key pair"
  default     = "tesi-aws"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# Route Table
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "subnet1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.main.id
}

# Subnets
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet1_cidr
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet2_cidr
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true
}

# Security Groups
resource "aws_security_group" "default_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instances
resource "aws_instance" "jenkins" {
  ami                          = "ami-01e444924a2233b07"
  instance_type                = var.instance_type
  subnet_id                    = aws_subnet.subnet1.id
  associate_public_ip_address  = true
  vpc_security_group_ids       = [aws_security_group.default_sg.id]
  key_name                     = var.key_name

  tags = {
    Name = "Jenkins"
  }

  user_data = <<-EOF
              #!/bin/bash
              exec > /var/log/user-data.log 2>&1
              set -o xtrace

              retry_command() {
                local retries=5
                local count=0
                until "$@"; do
                  exit=$?
                  count=$((count + 1))
                  if [ $count -lt $retries ]; then
                    sleep 10
                  else
                    return $exit
                  fi
                done
                return 0
              }

              echo "Updating apt repository..."
              retry_command sudo apt-get update -y
              echo "Installing dependencies..."
              retry_command sudo apt-get install -y fontconfig openjdk-17-jre git gnupg

              echo "Adding Jenkins repository key..."
              retry_command curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
              /usr/share/keyrings/jenkins-keyring.asc > /dev/null

              echo "Adding Jenkins repository..."
              echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee \
              /etc/apt/sources.list.d/jenkins.list > /dev/null

              echo "Updating apt repository again..."
              retry_command sudo apt-get update
              echo "Installing Jenkins..."
              retry_command sudo apt-get install -y jenkins

              echo "Starting Jenkins service..."
              sudo systemctl start jenkins
              sudo systemctl enable jenkins

              echo "Allowing port 8080 through UFW..."
              sudo ufw allow 8080
              EOF
}


resource "aws_instance" "my_ubuntu" {
  ami                          = "ami-01e444924a2233b07"
  instance_type                = var.instance_type
  subnet_id                    = aws_subnet.subnet1.id
  associate_public_ip_address  = true
  vpc_security_group_ids       = [aws_security_group.default_sg.id]
  key_name                     = var.key_name

  tags = {
    Name = "My Ubuntu"
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install -y docker.io
              sudo systemctl start docker
              sudo usermod -aG docker ubuntu
              EOF
}

resource "aws_instance" "my_windows" {
  ami                          = "ami-034de56da2366e342"
  instance_type                = var.instance_type
  subnet_id                    = aws_subnet.subnet2.id
  associate_public_ip_address  = true
  vpc_security_group_ids       = [aws_security_group.default_sg.id]
  key_name                     = var.key_name

  tags = {
    Name = "My Windows"
  }

  user_data = <<-EOF
              <powershell>
              [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
              Invoke-WebRequest -Uri https://download.docker.com/win/stable/Docker%20Desktop%20Installer.exe -OutFile DockerDesktopInstaller.exe
              Start-Process -FilePath DockerDesktopInstaller.exe -ArgumentList "/install", "/quiet", "/norestart" -NoNewWindow -Wait
              </powershell>
              EOF
}

# S3 Bucket
resource "aws_s3_bucket" "jenkins_artifacts" {
  bucket = "jenkins-artifacts-bucket-123456"

  tags = {
    Name        = "Jenkins Artifacts"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_versioning" "jenkins_artifacts_versioning" {
  bucket = aws_s3_bucket.jenkins_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Outputs
output "jenkins_url" {
  value = aws_instance.jenkins.public_dns
}

output "ubuntu_ip" {
  value = aws_instance.my_ubuntu.public_ip
}

output "windows_ip" {
  value = aws_instance.my_windows.public_ip
}

output "s3_bucket_name" {
  value = aws_s3_bucket.jenkins_artifacts.bucket
}
