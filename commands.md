Run the Services:

To start your services, use the following command:

docker-compose up -d

docker-compose down
docker-compose -f docker-compose.yml -f docker-compose.override.yml up --build
# For production
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up --build





To run the end-to-end tests, use the following command:

docker-compose -f docker-compose.e2e.yml up --abort-on-container-exit
/var/lib/jenkins/secrets/initialAdminPassword

cd /home/ubuntu/ecommerce-django-react
ls -la media/images


ssh -i "C:\Users\sammo\.ssh\tesi-aws.pem" ec2-user@3.122.56.6
ssh -i "C:\Users\sammo\.ssh\tesi-aws.pem" ec2-user@18.195.65.211

ssh -i "C:\Users\sammo\.ssh\tesi-aws.pem" ubuntu@3.76.217.10
ssh -i "C:\Users\sammo\.ssh\tesi-aws.pem" ubuntu@18.184.167.254
ssh -i "C:\Users\sammo\.ssh\tesi-aws.pem" ubuntu@3.79.240.158

check if docker and docker compose installed :
docker ps
docker-compose --version

Having logs for the SSH :
ssh -vvv -i "C:\Users\sammo\.ssh\tesi-aws.pem" ubuntu@3.70.222.92

ping 3.70.222.92
df -h
lsblk

Check Resources:
terraform state list

check status of Jenkins :
sudo systemctl status jenkins

Restart Jenkins :
sudo systemctl restart jenkins


Get the Jinkins Admin Password:
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

Check status of Docker :
sudo systemctl status docker


Check status of SSH:
sudo systemctl status sshd

 reboot your system:
sudo reboot

Doing Apply without writing "yes":
terraform apply -auto-approve

Destroying one instance only :
terraform destroy -target="aws_instance.jenkins" -auto-approve

terraform refresh

.\env\Scripts\activate  
deactivate

python manage.py runserver   
npm start


git add Jenkinsfile
git commit -m "Update Jenkinsfile 251"
git push origin main

sudo cat /var/log/user-data.log
7
You don't have to write the full code only give me the part/s need to be modified, change or updated
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

docker build -t skudsi/ecommerce-django-react-frontend:latest -f frontend/Dockerfile .
docker tag skudsi/ecommerce-django-react-frontend:latest index.docker.io/skudsi/ecommerce-django-react-frontend:latest
docker push index.docker.io/skudsi/ecommerce-django-react-frontend:latest

docker build -t skudsi/ecommerce-django-react-backend:latest -f backend/Dockerfile .
docker tag skudsi/ecommerce-django-react-backend:latest index.docker.io/skudsi/ecommerce-django-react-backend:latest
docker push skudsi/ecommerce-django-react-backend:latest


git add .
git commit -m "Update configuration v104"
git push origin main

Please dont use StrictHostKeyChecking-no and use StrictHostKeyChecking=no instead


Update Jenkins Configuration
Ensure the Jenkins master is correctly configured to recognize and use the new agent:

Go to Manage Jenkins > Manage Nodes and Clouds:

Add a new node (e.g., docker-agent).
Configure the New Node:

Provide necessary details like the node name, remote root directory, number of executors, and labels (docker).
Launch Method:


Choose the appropriate launch method (e.g., Launch agent via SSH or Launch agent via Java Web Start).


Adding SSH Credentials to Jenkins
Open Jenkins:

Go to your Jenkins instance URL: http://18.195.72.28:8080.
Open Credentials Configuration:

Click on Manage Jenkins from the left-hand side menu.
Select Manage Credentials.
Select Domain:

If you have not set up a specific domain for your credentials, select (global).
Add New Credentials:

Click on Add Credentials (usually on the left-hand side).
In the Kind dropdown, select SSH Username with private key.
Configure SSH Credentials:

Scope: Choose Global to make the credentials available to all jobs.
ID: (Optional) Provide an ID for the credentials for easier reference, e.g., tesi-aws.
Description: Provide a description for the credentials (e.g., SSH key for Jenkins agent).
Username: Enter the SSH username, which is usually ubuntu for AWS EC2 instances.
Private Key: Select Enter directly and paste the contents of your .pem file into the provided text box:
plaintext


Click OK to save the credentials.
Configuring Jenkins Agent
Open Jenkins Nodes Configuration:

Go to Manage Jenkins.
Select Manage Nodes and Clouds.
Click on New Node.
Configure New Node:

Node Name: Enter a name for your agent, e.g., docker-agent.
Type: Select Permanent Agent.
Click OK.
Configure Node Details:

Remote root directory: Enter the directory where Jenkins will store files on the agent, e.g., /home/ubuntu/jenkins.
Labels: Add docker to label the agent (if needed).
Usage: Use this node as much as possible.
Launch method: Select Launch agents via SSH.
Host: Enter the public IP or DNS of the agent, e.g., your-agent-public-ip.
Credentials: Select the SSH credentials you added earlier.
Host Key Verification Strategy: Choose Manually trusted key verification or any other appropriate strategy.
Save and Launch:

Click Save.
Jenkins will attempt to connect to the agent using the provided SSH credentials.


sudo systemctl daemon-reload
sudo systemctl restart jenkins



To destroy and remove everything properly without creating the S3 bucket again, you need to update your backend configuration to use a local backend temporarily, then destroy all resources. Here are the steps to do that:

Update the Backend to Local:

Change your main.tf to use a local backend instead of the S3 backend.

hcl
Copy code
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
Reinitialize Terraform with the Local Backend:

Reinitialize Terraform to use the local backend.

bash
Copy code
terraform init -reconfigure
Destroy the Existing Infrastructure:

Destroy all resources using the local backend.

bash
Copy code
terraform destroy



Complete Commands for PowerShell

Delete the .terraform directory:


Remove-Item -Recurse -Force .terraform
Remove-Item -Force .terraform.lock.hcl
Remove-Item -Force terraform.tfstate

create the S3 bucket before :
aws s3api create-bucket --bucket jenkins-artifacts-bucket-123456 --region eu-central-1 --create-bucket-configuration LocationConstraint=eu-central-1

terraform init

create the Table before:
aws dynamodb create-table --table-name terraform-lock-table --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 --region eu-central-1

terraform import aws_s3_bucket.jenkins_artifacts jenkins-artifacts-bucket-123456
terraform import aws_dynamodb_table.terraform_lock terraform-lock-table

Download the state file again:

aws s3 cp s3://jenkins-artifacts-bucket-123456/terraform/state/terraform.tfstate ./terraform.tfstate --region eu-central-1
aws s3 cp s3://jenkins-artifacts-bucket-123456/terraform/state/terraform.tfstate .\downloaded_state\terraform.tfstate --region eu-central-1

Upload the Updated State File to S3:

aws s3 cp ./terraform.tfstate s3://jenkins-artifacts-bucket-123456/terraform/state/terraform.tfstate --region eu-central-1

terraform apply

Destroy the infrastructure:

Delete All Objects and Versions in the S3 Bucket:

aws s3api delete-objects --bucket jenkins-artifacts-bucket-123456 --delete "$(aws s3api list-object-versions --bucket jenkins-artifacts-bucket-123456 --output=json --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')"

terraform destroy


Since the S3 bucket jenkins-artifacts-bucket-123456 does not exist, you'll need to recreate it before migrating the state back to the S3 backend. Here are the steps to proceed:

Step 1: Recreate the S3 Bucket and DynamoDB Table
Create the S3 Bucket and DynamoDB Table:

Update your main.tf to include the S3 bucket and DynamoDB table creation, then apply this configuration using the local backend.


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



terraform init
terraform apply


Step 2: Migrate State to S3 Backend
Reconfigure Backend to Use S3:

Update your main.tf to revert the backend configuration to use S3 and DynamoDB:

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

# Your existing resources...
Reinitialize Terraform with Migration:

Reinitialize Terraform to migrate the state back to S3:

terraform init -migrate-state




// email
                emailext body: """The build status is ${currentBuild.currentResult}, on project ${env.JOB_NAME} find test report in this url: ${BUILD_URL}/My_20Contacts/""",
                subject: """You got a faild build/job ${env.JOB_NAME} - ${env.BUILD_NUMBER} from jenkins""", 
                to: 'gagi.shmagi@gmail.com'
                