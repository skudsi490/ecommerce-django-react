# E-commerce Application Infrastructure Setup with Terraform and CI/CD Pipeline

![CI/CD Pipeline Diagram](./Screenshot%202024-06-26%20204238.png)

##  Explanation of `main.tf`

### Overview

The `main.tf` file defines and provisions AWS infrastructure to support the e-commerce application, integrating with the Jenkins CI/CD pipeline.

### Terraform Configuration

1. **Backend Configuration**:
    - **S3 Bucket**: Centralized Terraform state file storage.
    - **DynamoDB Table**: State locking.
    - **Region**: `eu-central-1`.
2. **Provider Configuration**:
    - AWS provider setup for `eu-central-1`.

### Networking

1. **VPC**:
    - CIDR block `10.0.0.0/16`.
2. **Subnets**:
    - Two public subnets (`10.0.1.0/24` and `10.0.2.0/24`).
3. **Internet Gateway**:
    - Enables internet access.
4. **Route Table**:
    - Routes traffic to the internet gateway.

### Security Groups

1. **Default Security Group**:
    - **Ingress Rules**: Allows necessary ports.
    - **Egress Rules**: Allows all outbound traffic.

### EC2 Instances

1. **Jenkins Master and Agent Instances**:
    - Provisions Jenkins instances with user data scripts.
2. **Ubuntu Instance**:
    - Provisions an Ubuntu instance with Docker and Nginx.

### S3 Bucket

1. **Jenkins Artifacts Bucket**:
    - Stores Jenkins artifacts with versioning enabled.

### Outputs

1. **Jenkins URL**: Public DNS name of Jenkins master instance.
2. **Jenkins Agent IP**: Public IP of Jenkins agent instance.
3. **Ubuntu Instance IP**: Public IP of the Ubuntu instance.
4. **S3 Bucket Name**: Name of the S3 bucket.

![AWS Infrastructure Overview](./Screenshot%202024-06-30%20182037.png)

## Docker and Docker Compose

### Docker

Docker automates application deployment in containers, ensuring consistency across environments.

### Dockerfile

1. **Stage 1**: Build React frontend.
    - **Base Image**: `node:20-buster`.
    - **Working Directory**: `/app`.
    - **Copy Files**: `package.json`, `package-lock.json`.
    - **Environment Variables**: `REACT_APP_BACKEND_URL`.
    - **Install Dependencies**: `npm install`.
    - **Copy Source Code**: React frontend.
    - **Build Frontend**: `npm run build`.
2. **Stage 2**: Setup Django backend and copy frontend build files.
    - **Base Image**: `python:3.9-slim`.
    - **Environment Variables**: Disable bytecode, unbuffered mode.
    - **Working Directory**: `/app`.
    - **Install Dependencies**: `requirements.txt`.
    - **Copy Source Code**: Django backend.
    - **Copy Static and Media Files**.
    - **Install Additional Tools**: `netcat-openbsd`, `procps`, `curl`, `net-tools`.
    - **Set Permissions**: Entrypoint script.
    - **Final Configuration**: Directories for static files and Gunicorn logs.

### Docker Compose

**Configuration** (`docker-compose.yml`):

1. **Services**:
    - **db**: PostgreSQL database.
        - **Image**: `postgres:13`.
        - **Environment Variables**: Database name, user, password.
        - **Volumes**: Persist data.
        - **Networks**: `app-network`.
    - **web**: Django web application.
        - **Build**: Context, Dockerfile, build arguments.
        - **Image**: `skudsi/ecommerce-django-react-web:latest`.
        - **Environment Variables**: Django, PostgreSQL.
        - **Volumes**: Needed directories and files.
        - **Depends On**: `db`.
        - **Ports**: `8000:8000`.
        - **Healthcheck**: Ensure web service is running.
        - **Networks**: `app-network`.
2. **Volumes**: Named volumes for PostgreSQL data.
3. **Networks**: Custom bridge network (`app-network`).

### Entrypoint Script (`entrypoint.sh`)

1. **Wait for PostgreSQL**.
2. **Apply Database Migrations**.
3. **Load Initial Data**.
4. **Set Permissions**.
5. **Collect Static Files**.
6. **Create Log Directory**.
7. **Start Server**.

## Jenkins CI/CD Pipeline (`Jenkinsfile`)

### Key Components

1. **Agent**: Runs on `docker`.
2. **Environment Variables**: Repository URL, Docker image, AWS credentials, S3 bucket, Django settings, PostgreSQL configuration, notification settings.
3. **Stages**:
    - **Pre-Cleanup**.
    - **Install AWS CLI**.
    - **Checkout**.
    - **Build Locally**.
    - **Test Locally**.
    - **Publish Report**.
    - **Test Docker Login**.
    - **Build and Push Docker Image**.
    - **Deploy to Ubuntu**.
4. **Post Actions**: Notifications to Slack and email on failure.

### Workflow

1. **Infrastructure Provisioning**: `terraform init`, `terraform plan`, `terraform apply`.
2. **CI/CD Pipeline Execution**: Jenkinsfile automation.

### Relation Between Jenkinsfile and Terraform

- **Jenkins EC2 Instance**: Created by Terraform for CI/CD.
- **S3 Bucket**: Used for Terraform state and Jenkins artifacts.
- **Ubuntu Instance**: Target for deployment.
- **AWS Credentials**: Provided for AWS operations.

![Jenkins Pipeline Stages](./Screenshot%202024-07-01%20162544.png)

## Summary

This CI/CD pipeline ensures a seamless workflow from code commit to deployment. Terraform provisions the necessary infrastructure, while Jenkins automates the build, test, and deployment process, providing a scalable, consistent, and efficient environment for continuous integration and deployment of the e-commerce application.
