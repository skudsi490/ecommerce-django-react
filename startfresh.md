Switch to Local Backend: Modify your main.tf file to use a local backend.
hcl
Copy code
terraform {
  backend "local" {
    path = "terraform.tfstate"
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

# The rest of your configuration
Reinitialize Terraform: Run the following command to reinitialize Terraform with the local backend.
sh
Copy code
terraform init -reconfigure
Destroy the Infrastructure: Once Terraform has been reinitialized to use the local backend, you can destroy the infrastructure.
sh
Copy code
terraform destroy
This should work without requiring the S3 bucket to be available.




Given that you want to start from scratch and avoid creating the S3 bucket and DynamoDB table manually before initializing Terraform, you can follow these steps:

Clean Up Old Terraform Files: Remove existing .terraform directories and state files.
Start with Local Backend: Initialize Terraform using a local backend.
Create Infrastructure Including S3 Bucket and DynamoDB Table: Apply the configuration to create the necessary resources.
Migrate State to S3 Backend: Reconfigure Terraform to use the S3 backend and migrate the state.
Detailed Steps
Step 1: Clean Up Old Terraform Files
Run the following commands in PowerShell to remove existing Terraform files:

powershell
Copy code
Remove-Item -Recurse -Force .terraform
Remove-Item -Force .terraform.lock.hcl
Remove-Item -Force terraform.tfstate
Step 2: Start with Local Backend
Update your main.tf to use the local backend:

hcl
Copy code
terraform {
  backend "local" {
    path = "terraform.tfstate"
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

# Variables and resources go here, including S3 bucket and DynamoDB table
Step 3: Initialize Terraform with Local Backend
Initialize Terraform:

powershell
Copy code
terraform init
Step 4: Apply Configuration to Create Resources
Create your infrastructure, including the S3 bucket and DynamoDB table:

powershell
Copy code
terraform apply
Make sure your main.tf includes the resources for the S3 bucket and DynamoDB table:

hcl
Copy code
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
Step 5: Migrate State to S3 Backend
Once your resources are created, update main.tf to use the S3 backend:

hcl
Copy code
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

# Variables and resources go here
Reinitialize Terraform with the new backend configuration and migrate the state:

powershell
Copy code
terraform init -migrate-state