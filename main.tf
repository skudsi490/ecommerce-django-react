terraform {
  backend "s3" {
    bucket         = "jenkins-artifacts-bucket-123456"
    key            = "terraform/state/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform-lock-table"
  }
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
  default = "t3.medium"
}

variable "key_name" {
  description = "Name of the SSH key pair"
  default     = "tesi-aws"
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_lock" {
  name         = "terraform-lock-table"
  billing_mode = "PROVISIONED"
  read_capacity = 5
  write_capacity = 5
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
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

# Jenkins EC2 Instance
resource "aws_instance" "jenkins" {
  ami                          = "ami-01e444924a2233b07"
  instance_type                = var.instance_type
  subnet_id                    = aws_subnet.subnet1.id
  associate_public_ip_address  = true
  vpc_security_group_ids       = [aws_security_group.default_sg.id]
  key_name                     = var.key_name
  instance_initiated_shutdown_behavior = "stop"

  ebs_block_device {
    device_name = "/dev/sdh"
    volume_size = 30
    volume_type = "gp2"
  }

  lifecycle {
    ignore_changes  = [associate_public_ip_address]
  }

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
                    echo "Retry $count/$retries:"
                    sleep 10
                  else
                    echo "Command failed after $retries attempts."
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
              retry_command sudo systemctl start jenkins
              retry_command sudo systemctl enable jenkins

              echo "Installing Docker..."
              retry_command sudo apt-get update -y
              retry_command sudo apt-get install -y docker.io
              retry_command sudo systemctl start docker
              retry_command sudo systemctl enable docker
              retry_command sudo usermod -aG docker jenkins
              retry_command sudo usermod -aG docker ubuntu

              echo "Installing Docker Compose..."
              retry_command sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-\$(uname -s)-\$(uname -m)" -o /usr/local/bin/docker-compose
              retry_command sudo chmod +x /usr/local/bin/docker-compose
              retry_command sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

              echo "Installing jq..."
              retry_command sudo apt-get install -y jq

              echo "Configuring swap space..."
              retry_command sudo fallocate -l 4G /swapfile
              retry_command sudo chmod 600 /swapfile
              retry_command sudo mkswap /swapfile
              retry_command sudo swapon /swapfile
              echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

              echo "Allowing port 8080 through UFW..."
              retry_command sudo ufw allow 8080

              echo "Cleaning up unnecessary files to free up disk space..."
              retry_command sudo docker system prune -a -f
              retry_command sudo rm -rf /var/lib/jenkins/workspace/*
              retry_command sudo rm -rf /var/lib/jenkins/logs/*
              retry_command sudo apt-get clean
              EOF
}

# Jenkins Agent EC2 Instance
resource "aws_instance" "jenkins_agent" {
  ami                          = "ami-01e444924a2233b07"
  instance_type                = var.instance_type
  subnet_id                    = aws_subnet.subnet1.id
  associate_public_ip_address  = true
  vpc_security_group_ids       = [aws_security_group.default_sg.id]
  key_name                     = var.key_name
  instance_initiated_shutdown_behavior = "stop"

  ebs_block_device {
    device_name = "/dev/sdh"
    volume_size = 30
    volume_type = "gp2"
  }

  lifecycle {
    ignore_changes  = [associate_public_ip_address]
  }

  tags = {
    Name = "Jenkins Agent"
  }

  user_data = <<-EOF
              #!/bin/bash
              exec > /var/log/user-data.log 2>&1
              set -o xtrace

              sudo apt-get update -y
              sudo apt-get install -y openjdk-17-jre docker.io jq
              sudo systemctl start docker
              sudo systemctl enable docker
              sudo usermod -aG docker ubuntu

              echo "Configuring swap space..."
              sudo fallocate -l 4G /swapfile
              sudo chmod 600 /swapfile
              sudo mkswap /swapfile
              sudo swapon /swapfile
              echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

              wget -O /home/ubuntu/agent.jar http://<jenkins-server>/jnlpJars/agent.jar

              nohup java -jar /home/ubuntu/agent.jar -jnlpUrl http://<jenkins-server>/computer/<node-name>/jenkins-agent.jnlp -secret <agent-secret> &

              # Cleanup to free up space
              sudo apt-get clean
              sudo docker system prune -a -f
              sudo rm -rf /var/lib/jenkins/workspace/*
              sudo rm -rf /var/lib/jenkins/logs/*
              EOF
}

# My Ubuntu EC2 Instance
resource "aws_instance" "my_ubuntu" {
  ami                          = "ami-01e444924a2233b07"
  instance_type                = var.instance_type
  subnet_id                    = aws_subnet.subnet1.id
  associate_public_ip_address  = true
  vpc_security_group_ids       = [aws_security_group.default_sg.id]
  key_name                     = var.key_name
  instance_initiated_shutdown_behavior = "stop"

  ebs_block_device {
    device_name = "/dev/sdh"
    volume_size = 30
    volume_type = "gp2"
  }

  lifecycle {
    ignore_changes  = [associate_public_ip_address]
  }

  tags = {
    Name = "My Ubuntu"
  }

  user_data = <<-EOF
    #!/bin/bash
    exec > /var/log/user-data.log 2>&1
    set -o xtrace

    echo "Updating apt repository..."
    sudo apt update -y

    echo "Installing Docker..."
    sudo apt install -y docker.io
    echo "Starting Docker..."
    sudo systemctl start docker
    sudo systemctl enable docker
    echo "Adding user to Docker group..."
    sudo usermod -aG docker ubuntu

    echo "Installing jq..."
    sudo apt-get install -y jq

    echo "Installing Nginx..."
    sudo apt install -y nginx
    echo "Starting Nginx..."
    sudo systemctl start nginx
    sudo systemctl enable nginx

    echo "Configuring Nginx for Django application..."
    sudo bash -c 'cat > /etc/nginx/sites-available/default <<EOL
    server {
        listen 80;
        server_name _;

        location / {
            root /usr/share/nginx/html;
            index index.html;
            try_files $uri /index.html;
        }

        # Proxy pass for API requests
        location /api/ {
            proxy_pass http://localhost:8000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
    EOL'
    sudo nginx -t
    sudo systemctl reload nginx

    echo "Configuring swap space..."
    sudo fallocate -l 4G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
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

output "jenkins_agent_ip" {
  value = aws_instance.jenkins_agent.public_ip
}

output "ubuntu_ip" {
  value = aws_instance.my_ubuntu.public_ip
}

output "s3_bucket_name" {
  value = aws_s3_bucket.jenkins_artifacts.bucket
}
