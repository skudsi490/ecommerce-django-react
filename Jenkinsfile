pipeline {
    agent {
        label 'docker'
    }
    environment {
        REPO_URL = 'https://github.com/skudsi490/ecommerce-django-react.git'
        DOCKER_IMAGE_BACKEND = 'skudsi/ecommerce-django-react-backend'
        DOCKER_IMAGE_FRONTEND = 'skudsi/ecommerce-django-react-frontend'
        S3_BUCKET = 'jenkins-artifacts-bucket-123456'
        NODE_OPTIONS = "--openssl-legacy-provider"
        DOCKERHUB_CREDENTIALS = credentials('dockerhub')
        AWS_ACCESS_KEY_ID = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
        DJANGO_SETTINGS_MODULE = 'backend.settings'
        PYTHONPATH = '/app:/app/backend:/app/base'
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
                script {
                    echo "Current branch: ${env.GIT_BRANCH}"
                }
            }
        }

        stage('Install Terraform') {
            steps {
                sh '''
                if ! [ -x "$(command -v terraform)" ]; then
                    echo "Terraform not found, installing..."
                    wget https://releases.hashicorp.com/terraform/1.0.0/terraform_1.0.0_linux_amd64.zip
                    unzip terraform_1.0.0_linux_amd64.zip
                    sudo mv terraform /usr/local/bin/
                fi
                '''
            }
        }

        stage('Test Docker Login') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                        sh 'docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD'
                    }
                    echo 'Docker login successful!'
                }
            }
        }

        stage('Clean Docker') {
            steps {
                sh '''
                echo "Cleaning up docker"
                docker system prune -af --volumes || true
                sudo apt-get clean || true
                sudo apt-get autoremove -y || true
                df -h
                '''
            }
        }

        stage('Build and Push Docker Images') {
            parallel {
                stage('Build Backend') {
                    steps {
                        script {
                            withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                                dir('backend') {
                                    docker.withRegistry('https://index.docker.io/v1/', '') {
                                        def backendImage = docker.build("${DOCKER_IMAGE_BACKEND}:latest", "..")
                                        backendImage.push('latest')
                                    }
                                }
                            }
                        }
                    }
                }
                stage('Build Frontend') {
                    steps {
                        script {
                            withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                                dir('frontend') {
                                    docker.withRegistry('https://index.docker.io/v1/', '') {
                                        def frontendImage = docker.build("${DOCKER_IMAGE_FRONTEND}:latest", "..")
                                        frontendImage.push('latest')
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        stage('Install Docker Compose') {
            steps {
                sh '''
                if ! [ -x "$(command -v docker-compose)" ]; then
                  echo "Docker Compose not found, installing..."
                  sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                  sudo chmod +x /usr/local/bin/docker-compose
                fi
                '''
            }
        }

        stage('Install Python 3.9.18') {
            steps {
                retry(3) {
                    sh '''
                    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
                      echo "Waiting for other apt-get process to release lock..."
                      sleep 5
                    done
                    sudo apt-get update
                    sudo apt-get install -y software-properties-common
                    sudo add-apt-repository ppa:deadsnakes/ppa
                    sudo apt-get update
                    sudo apt-get install -y python3.9 python3.9-venv python3.9-dev
                    '''
                }
            }
        }

        stage('Install Dependencies') {
            steps {
                sh '''
                python3.9 -m venv venv
                bash -c "source venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt"
                '''
            }
        }

        stage('Install Chrome and ChromeDriver') {
            steps {
                sh '''
                sudo apt-get update
                sudo apt-get install -y wget unzip
                wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
                sudo sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list'
                sudo apt-get update
                sudo apt-get install -y --no-install-recommends google-chrome-stable
                wget https://chromedriver.storage.googleapis.com/114.0.5735.90/chromedriver_linux64.zip
                unzip -o chromedriver_linux64.zip
                sudo mv chromedriver /usr/local/bin/
                sudo chmod +x /usr/local/bin/chromedriver
                '''
            }
        }

        stage('Clean PyCache') {
            steps {
                sh '''
                find . -type d -name "__pycache__" -exec rm -rf {} +
                find . -type f -name "*.pyc" -delete
                '''
            }
        }

        stage('Unit Tests') {
            steps {
                sh '''
                # Clean the workspace to ensure no old test files are present
                rm -rf archive

                mkdir -p backend/reports
                bash -c "source venv/bin/activate && docker-compose run backend pytest backend/tests --junitxml=/app/reports/unit_tests.xml"
                '''
            }
            post {
                always {
                    junit 'backend/reports/unit_tests.xml'
                }
            }
        }

        stage('Integration Tests') {
            steps {
                sh '''
                mkdir -p backend/reports
                bash -c "source venv/bin/activate && docker-compose run backend pytest backend/tests --junitxml=/app/reports/integration_tests.xml"
                '''
            }
            post {
                always {
                    junit 'backend/reports/integration_tests.xml'
                }
            }
        }

        stage('E2E Tests') {
            steps {
                sh '''
                mkdir -p frontend/reports
                bash -c "source venv/bin/activate && docker-compose -f docker-compose.e2e.yml run frontend pytest frontend/tests --junitxml=/app/reports/e2e_tests.xml"
                '''
            }
            post {
                always {
                    junit 'frontend/reports/e2e_tests.xml'
                }
            }
        }

        stage('Push Docker Images') {
            steps {
                script {
                    echo "Current build result: ${currentBuild.result}"
                    withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                        docker.withRegistry('https://index.docker.io/v1/', '') {
                            docker.image("${DOCKER_IMAGE_BACKEND}:latest").push('latest')
                            docker.image("${DOCKER_IMAGE_FRONTEND}:latest").push('latest')
                        }
                    }
                }
            }
        }

        stage('Archive Artifacts') {
            steps {
                sh '''
                mkdir -p archive/backend archive/frontend
                cp -r backend/* archive/backend/
                cp -r frontend/* archive/frontend/
                '''
                withCredentials([string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                                 string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                    export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                    export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                    aws s3 sync archive/ s3://${S3_BUCKET}/
                    unset AWS_ACCESS_KEY_ID
                    unset AWS_SECRET_ACCESS_KEY
                    '''
                }
            }
        }

        stage('Deploy to Ubuntu') {
            steps {
                script {
                    echo "Deploying to Ubuntu"
                    echo "Current branch: ${env.GIT_BRANCH}"
                    echo "Current build result: ${currentBuild.result}"
                    withCredentials([string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                                     string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'),
                                     sshUserPrivateKey(credentialsId: 'tesi_aws', keyFileVariable: 'SSH_KEY')]) {
                        // Ensure the Terraform state is downloaded
                        sh '''
                        export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                        export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                        aws s3 cp s3://jenkins-artifacts-bucket-123456/terraform/state/terraform.tfstate terraform.tfstate
                        unset AWS_ACCESS_KEY_ID
                        unset AWS_SECRET_ACCESS_KEY
                        '''
                        // Ensure jq is installed
                        sh '''
                        if ! [ -x "$(command -v jq)" ]; then
                          echo "jq not found, installing..."
                          sudo apt-get update -y
                          sudo apt-get install -y jq
                        fi
                        '''
                        script {
                            def terraformState = readFile 'terraform.tfstate'
                            def ubuntuIp = sh(script: "jq -r '.resources[] | select(.type==\"aws_instance\" and .name==\"my_ubuntu\").instances[0].attributes.public_ip' terraform.tfstate", returnStdout: true).trim()

                            echo "Ubuntu IP: ${ubuntuIp}"

                            if (ubuntuIp) {
                                env.MY_UBUNTU_IP = ubuntuIp
                                sh '''
                                ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${MY_UBUNTU_IP} "mkdir -p /home/ubuntu/ecommerce-django-react"

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
                                # Ensure AWS CLI is installed
                                if ! [ -x "$(command -v aws)" ]; then
                                  echo "AWS CLI not found, installing..."
                                  sudo apt-get install -y unzip
                                  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                                  unzip awscliv2.zip
                                  sudo ./aws/install
                                fi
                                # Export AWS credentials
                                export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                                export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                                echo "Downloading artifacts from S3..."
                                aws s3 sync s3://${S3_BUCKET}/ /home/ubuntu/ecommerce-django-react/
                                cd /home/ubuntu/ecommerce-django-react
                                echo "Bringing down existing Docker containers..."
                                docker-compose down || exit 1
                                echo "Pulling latest Docker images..."
                                docker-compose pull || exit 1
                                echo "Starting Docker containers..."
                                docker-compose up -d || exit 1
                                echo "Deployment successful!"
                                EOF
                                '''
                            } else {
                                error("Missing ubuntu_ip in terraform state.")
                            }
                        }
                    }
                }
            }
        }

        stage('Deploy to Windows') {
            steps {
                script {
                    echo "Deploying to Windows"
                    echo "Current branch: ${env.GIT_BRANCH}"
                    echo "Current build result: ${currentBuild.result}"
                    withCredentials([string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                                     string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                        // Ensure the Terraform state is downloaded
                        sh '''
                        export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                        export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                        aws s3 cp s3://jenkins-artifacts-bucket-123456/terraform/state/terraform.tfstate terraform.tfstate
                        unset AWS_ACCESS_KEY_ID
                        unset AWS_SECRET_ACCESS_KEY
                        '''
                        // Ensure jq is installed
                        sh '''
                        if ! [ -x "$(command -v jq)" ]; then
                          echo "jq not found, installing..."
                          sudo apt-get update -y
                          sudo apt-get install -y jq
                        fi
                        '''
                        script {
                            def terraformState = readFile 'terraform.tfstate'
                            def windowsIp = sh(script: "jq -r '.resources[] | select(.type==\"aws_instance\" and .name==\"my_windows\").instances[0].attributes.public_ip' terraform.tfstate", returnStdout: true).trim()

                            echo "Windows IP: ${windowsIp}"

                            if (windowsIp) {
                                env.MY_WINDOWS_IP = windowsIp
                                sh '''
                                powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "
                                $ErrorActionPreference = 'Stop';
                                $winrm = Get-WinRmInstance -HostName ${MY_WINDOWS_IP} -Username 'Administrator' -Password (Get-Secret -Name 'aws-instance-password')
                                Invoke-WinRmCommand -WinRm $winrm -Command '
                                if (!(Test-Path -Path C:\\ecommerce-django-react)) {
                                    New-Item -ItemType Directory -Path C:\\ecommerce-django-react
                                }
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
}
