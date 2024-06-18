pipeline {
    agent {
        label 'docker'
    }
    environment {
        REPO_URL = 'https://github.com/skudsi490/ecommerce-django-react.git'
        DOCKER_IMAGE_BACKEND = 'skudsi/ecommerce-django-react-backend'
        DOCKER_IMAGE_FRONTEND = 'skudsi/ecommerce-django-react-frontend'
        S3_BUCKET = 'jenkins-artifacts-bucket-123456'
        JIRA_URL = 'https://ecommerce-django-react.atlassian.net/'
        JIRA_USER = 'skudsi490@gmail.com'
        NODE_OPTIONS = "--openssl-legacy-provider"
        JIRA_API_TOKEN = credentials('JIRA_API_TOKEN')
        JIRA_SITE = 'ecommerce-django-react'
        JIRA_PROJECT_KEY = 'TD'
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
                
                echo "Disk usage after cleanup:"
                df -h
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

        stage('Push Docker Images') {
            when {
                allOf {
                    branch 'main'
                    expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
                }
            }
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
            when {
                allOf {
                    branch 'main'
                    expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
                }
            }
            steps {
                script {
                    withCredentials([string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                                     string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                        sh 'terraform output -json > terraform_output.json'
                        def terraformOutputs = readJSON file: 'terraform_output.json'
                        env.MY_UBUNTU_IP = terraformOutputs.ubuntu_ip.value
                        sh '''
                        export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                        export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                        ssh-agent bash -c 'ssh-add ~/.ssh/id_rsa && scp -o StrictHostKeyChecking=no terraform_output.json ubuntu@${MY_UBUNTU_IP}:/home/ubuntu/terraform_output.json'
                        unset AWS_ACCESS_KEY_ID
                        unset AWS_SECRET_ACCESS_KEY
                        '''
                    }

                    sshagent(credentials: ['ssh-key-credentials']) {
                        sh '''
                        set -e
                        echo "Deploying to Ubuntu instance at ${MY_UBUNTU_IP}"
                        ssh -o StrictHostKeyChecking=no ubuntu@${MY_UBUNTU_IP} <<EOF
                        set -e
                        if ! [ -x "$(command -v docker-compose)" ]; then
                          echo "Docker Compose not found, installing..."
                          sudo apt update
                          sudo apt install docker-compose -y
                        fi
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
                    }
                }
            }
        }

        stage('Deploy to Windows') {
            when {
                allOf {
                    branch 'main'
                    expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
                }
            }
            steps {
                script {
                    withCredentials([string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                                     string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                        sh 'terraform output -json > terraform_output.json'
                        def terraformOutputs = readJSON file: 'terraform_output.json'
                        env.MY_WINDOWS_IP = terraformOutputs.windows_ip.value
                        sh '''
                        export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                        export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
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
                        unset AWS_ACCESS_KEY_ID
                        unset AWS_SECRET_ACCESS_KEY
                        '''
                    }
                }
            }
        }

        stage('Post to Jira') {
            when {
                allOf {
                    branch 'main'
                    expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
                }
            }
            steps {
                script {
                    def jiraComment = "Build ${env.JOB_NAME} #${env.BUILD_NUMBER} was successful. See details at ${env.BUILD_URL}"
                    jiraComment issueKey: "${JIRA_PROJECT_KEY}-${env.BUILD_NUMBER}", comment: jiraComment
                }
            }
        }

        stage('Verify Deployment on Instances') {
            steps {
                script {
                    withCredentials([string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                                     string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                        sh 'terraform output -json > terraform_output.json'
                        def terraformOutputs = readJSON file: 'terraform_output.json'
                        def ubuntuIp = terraformOutputs.ubuntu_ip.value
                        def windowsIp = terraformOutputs.windows_ip.value
                        
                        // Verify deployment on Ubuntu instance
                        sshagent(credentials: ['ssh-key-credentials']) {
                            sh """
                            ssh -o StrictHostKeyChecking=no ubuntu@${ubuntuIp} <<EOF
                            docker-compose ps
                            EOF
                            """
                        }

                        // Verify deployment on Windows instance
                        sh """
                        export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                        export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                        powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "
                        $ErrorActionPreference = 'Stop';
                        $winrm = Get-WinRmInstance -HostName ${windowsIp} -Username 'Administrator' -Password (Get-Secret -Name 'aws-instance-password')
                        Invoke-WinRmCommand -WinRm $winrm -Command '
                        docker-compose ps
                        '
                        "
                        unset AWS_ACCESS_KEY_ID
                        unset AWS_SECRET_ACCESS_KEY
                        """
                    }
                }
            }
        }
    }

    post {
        failure {
            script {
                emailext (
                    to: 'skudsi490@gmail.com',
                    subject: "Build failed in Jenkins: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    body: "Check Jenkins logs for details."
                )
                def jiraComment = "Build ${env.JOB_NAME} #${env.BUILD_NUMBER} failed. Check Jenkins logs for details."
                jiraComment issueKey: "${JIRA_PROJECT_KEY}-${env.BUILD_NUMBER}", comment: jiraComment
            }
        }
    }   
}