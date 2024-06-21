pipeline {
    agent {
        label 'docker'
    }
    environment {
        REPO_URL = 'https://github.com/skudsi490/ecommerce-django-react.git'
        DOCKER_IMAGE_BACKEND = 'skudsi/ecommerce-django-react-backend'
        DOCKER_IMAGE_FRONTEND = 'skudsi/ecommerce-django-react-frontend'
        DOCKERHUB_CREDENTIALS = credentials('dockerhub')
        AWS_ACCESS_KEY_ID = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
        S3_BUCKET = 'jenkins-artifacts-bucket-123456'
        DJANGO_SETTINGS_MODULE = 'backend.settings'
        PYTHONPATH = '/app:/app/backend:/app/base'
        POSTGRES_DB = 'ecommerce'
        POSTGRES_USER = 'ecommerceuser'
        POSTGRES_PASSWORD = 'ecommercedbpassword'
        POSTGRES_HOST = 'db'
    }

    stages {
        stage('Pre-Cleanup') {
            steps {
                sh '''
                echo "Disk usage before cleanup:"
                df -h

                echo "Cleaning up workspace and Docker resources"
                docker system prune -af --volumes || true
                sudo rm -rf ${WORKSPACE}/*
                sudo apt-get clean || true
                sudo apt-get autoremove -y || true
                sudo rm -rf /var/lib/docker/tmp/*
                sudo rm -rf /var/lib/apt/lists/*

                if ! [ -x "$(command -v unzip)" ]; then
                    echo "Unzip not found, installing..."
                    sudo apt-get update -y
                    sudo apt-get install -y unzip
                fi

                echo "Disk usage after cleanup:"
                df -h
                '''
            }
        }

        stage('Install AWS CLI') {
            steps {
                sh '''
                if ! [ -x "$(command -v aws)" ]; then
                  echo "AWS CLI not found, installing..."
                  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                  unzip awscliv2.zip
                  sudo ./aws/install
                fi
                '''
            }
        }

        stage('Checkout') {
            steps {
                git url: "${REPO_URL}", branch: 'main'
            }
        }

        stage('Test Docker Login') {
            steps {
                script {
                    retry(3) {
                        withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                            sh 'echo $DOCKER_PASSWORD | docker login -u $DOCKER_USERNAME --password-stdin'
                        }
                    }
                }
            }
        }

        stage('Build and Push Docker Images') {
            parallel {
                stage('Build Backend') {
                    steps {
                        script {
                            docker.build("${DOCKER_IMAGE_BACKEND}:latest", "-f backend/Dockerfile .")
                        }
                    }
                }
                stage('Build Frontend') {
                    steps {
                        script {
                            sh '''
                            # Increase memory limit for Docker
                            docker build --memory 4g -t ${DOCKER_IMAGE_FRONTEND}:latest -f frontend/Dockerfile .
                            '''
                        }
                    }
                }
            }
        }

        stage('Push Docker Images') {
            steps {
                script {
                    docker.withRegistry('https://index.docker.io/v1/', 'dockerhub') {
                        docker.image("${DOCKER_IMAGE_BACKEND}:latest").push('latest')
                        docker.image("${DOCKER_IMAGE_FRONTEND}:latest").push('latest')
                    }
                }
            }
        }

        stage('Deploy to Ubuntu') {
            steps {
                script {
                    withCredentials([string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                                     string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'),
                                     sshUserPrivateKey(credentialsId: 'tesi_aws', keyFileVariable: 'SSH_KEY')]) {
                        sh '''
                        export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                        export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                        aws s3 cp s3://jenkins-artifacts-bucket-123456/terraform/state/terraform.tfstate terraform.tfstate
                        unset AWS_ACCESS_KEY_ID
                        unset AWS_SECRET_ACCESS_KEY
                        '''
                        def terraformState = readFile 'terraform.tfstate'
                        def ubuntuIp = sh(script: "jq -r '.resources[] | select(.type==\"aws_instance\" and .name==\"my_ubuntu\").instances[0].attributes.public_ip' terraform.tfstate", returnStdout: true).trim()
                        
                        if (ubuntuIp) {
                            env.MY_UBUNTU_IP = ubuntuIp
                            sh '''
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${MY_UBUNTU_IP} "mkdir -p /home/ubuntu/ecommerce-django-react/"
                            scp -o StrictHostKeyChecking=no -i ${SSH_KEY} docker-compose.yml ubuntu@${MY_UBUNTU_IP}:/home/ubuntu/ecommerce-django-react/ || (echo "Failed to copy docker-compose.yml" && exit 1)
                            scp -o StrictHostKeyChecking=no -i ${SSH_KEY} requirements.txt ubuntu@${MY_UBUNTU_IP}:/home/ubuntu/ecommerce-django-react/ || (echo "Failed to copy requirements.txt" && exit 1)
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${MY_UBUNTU_IP} <<EOF
                            set -e
                            if ! [ -x "$(command -v docker)" ]; then
                              echo "Docker not found, installing..."
                              sudo apt update
                              sudo apt install docker.io -y
                              sudo systemctl start docker
                              sudo systemctl enable docker
                              sudo usermod -aG docker ubuntu
                            fi
                            if ! [ -x "$(command -v docker-compose)" ]; then
                              echo "Docker Compose not found, installing..."
                              sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                              sudo chmod +x /usr/local/bin/docker-compose
                            fi
                            docker-compose -f /home/ubuntu/ecommerce-django-react/docker-compose.yml down
                            docker-compose -f /home/ubuntu/ecommerce-django-react/docker-compose.yml pull
                            docker-compose -f /home/ubuntu/ecommerce-django-react/docker-compose.yml up -d
                            EOF
                            '''
                        } else {
                            error("Missing ubuntu_ip in terraform state.")
                        }
                    }
                }
            }
        }

        stage('Deploy to Windows') {
            steps {
                script {
                    withCredentials([string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                                     string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                        sh '''
                        export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                        export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                        aws s3 cp s3://jenkins-artifacts-bucket-123456/terraform/state/terraform.tfstate terraform.tfstate
                        unset AWS_ACCESS_KEY_ID
                        unset AWS_SECRET_ACCESS_KEY
                        '''
                        def terraformState = readFile 'terraform.tfstate'
                        def windowsIp = sh(script: "jq -r '.resources[] | select(.type==\"aws_instance\" and .name==\"my_windows\").instances[0].attributes.public_ip' terraform.tfstate", returnStdout: true).trim()
                        
                        if (windowsIp) {
                            env.MY_WINDOWS_IP = windowsIp
                            sh '''
                            powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "
                            $ErrorActionPreference = 'Stop';
                            $winrm = Get-WinRmInstance -HostName ${MY_WINDOWS_IP} -Username 'Administrator' -Password (Get-Secret -Name 'aws-instance-password')
                            Invoke-WinRmCommand -WinRm $winrm -Command '
                            aws s3 sync s3://${S3_BUCKET}/ C:\\ecommerce-django-react
                            cd C:\\ecommerce-django-react
                            
                            docker-compose down
                            docker-compose pull
                            docker-compose up -d
                            '
                            "
                            '''
                        } else {
                            error("Missing windows_ip in terraform state.")
                        }
                    }
                }
            }
        }
    }
}
