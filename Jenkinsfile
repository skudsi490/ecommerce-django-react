pipeline {
    agent {
        label 'docker'
    }
    environment {
        REPO_URL = 'https://github.com/skudsi490/ecommerce-django-react.git'
        DOCKER_IMAGE_WEB = 'skudsi/ecommerce-django-react-web'
        DOCKERHUB_CREDENTIALS = credentials('dockerhub')
        AWS_ACCESS_KEY_ID = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
        AWS_STORAGE_BUCKET_NAME = 'jenkins-artifacts-bucket-123456'
        DJANGO_SETTINGS_MODULE = 'backend.settings'
        PYTHONPATH = '/app:/app/backend:/app/base'
        POSTGRES_DB = 'ecommerce'
        POSTGRES_USER = 'ecommerceuser'
        POSTGRES_PASSWORD = 'ecommercedbpassword'
        POSTGRES_HOST = 'db'
        REACT_APP_BACKEND_URL = 'http://3.76.217.10:8000'
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

        stage('Verify Required Files') {
            steps {
                sh '''
                echo "Contents of project root directory:"
                ls -la

                echo "Contents of static directory:"
                ls -la static || echo "No static directory found"

                echo "Contents of media directory:"
                ls -la media || echo "No media directory found"

                echo "Contents of pytest.ini:"
                cat pytest.ini || echo "pytest.ini file not found"
                '''
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

        stage('Build and Push Docker Image') {
            steps {
                script {
                    docker.build("${DOCKER_IMAGE_WEB}:latest", "--build-arg REACT_APP_BACKEND_URL=${REACT_APP_BACKEND_URL} .")
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                script {
                    docker.withRegistry('https://index.docker.io/v1/', 'dockerhub') {
                        docker.image("${DOCKER_IMAGE_WEB}:latest").push('latest')
                    }
                }
            }
        }

        stage('Fetch Terraform State') {
            steps {
                script {
                    withCredentials([string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                                     string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                        sh '''
                        export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                        export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                        aws s3 cp s3://${AWS_STORAGE_BUCKET_NAME}/terraform/state/terraform.tfstate terraform.tfstate
                        '''
                    }
                }
            }
        }

        stage('Deploy to Ubuntu') {
            steps {
                script {
                    def publicIp = sh(script: "jq -r '.resources[] | select(.type==\"aws_instance\" and .name==\"my_ubuntu\").instances[0].attributes.public_ip' terraform.tfstate", returnStdout: true).trim()
                    withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key', keyFileVariable: 'SSH_KEY')]) {
                        sh """
                        ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${publicIp} << 'EOF'
                        echo "Checking disk space and directory permissions..."
                        df -h
                        ls -la /home/ubuntu/ecommerce-django-react/
                        EOF

                        echo "Uploading files to remote server..."
                        scp -o StrictHostKeyChecking=no -i ${SSH_KEY} docker-compose.yml ubuntu@${publicIp}:/home/ubuntu/ecommerce-django-react/
                        scp -o StrictHostKeyChecking=no -i ${SSH_KEY} -r Dockerfile entrypoint.sh backend base frontend manage.py requirements.txt static media data_dump.json pytest.ini ubuntu@${publicIp}:/home/ubuntu/ecommerce-django-react/

                        echo "Verifying uploaded files on the server..."
                        ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${publicIp} << 'EOF'
                        ls -la /home/ubuntu/ecommerce-django-react/
                        EOF

                        echo "Running Docker Compose..."
                        ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${publicIp} << 'EOF'
                        if ! [ -x "$(command -v docker-compose)" ]; then
                            echo "Docker Compose not found, installing..."
                            sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                            sudo chmod +x /usr/local/bin/docker-compose
                        fi

                        cd /home/ubuntu/ecommerce-django-react/
                        docker-compose down || true
                        docker-compose up -d --build
                        EOF
                        """
                    }
                }
            }
        }

        stage('Run Django Migrations and Load Data') {
            steps {
                script {
                    def publicIp = sh(script: "jq -r '.resources[] | select(.type==\"aws_instance\" and .name==\"my_ubuntu\").instances[0].attributes.public_ip' terraform.tfstate", returnStdout: true).trim()
                    withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key', keyFileVariable: 'SSH_KEY')]) {
                        sh """
                        echo "Running Django migrations and loading data..."
                        ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${publicIp} << 'EOF'
                        cd /home/ubuntu/ecommerce-django-react/
                        docker-compose exec web python manage.py migrate
                        docker-compose exec web python manage.py loaddata data_dump.json
                        EOF
                        """
                    }
                }
            }
        }

        stage('Verify and Upload Media Files') {
            steps {
                script {
                    def publicIp = sh(script: "jq -r '.resources[] | select(.type==\"aws_instance\" and .name==\"my_ubuntu\").instances[0].attributes.public_ip' terraform.tfstate", returnStdout: true).trim()
                    withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key', keyFileVariable: 'SSH_KEY')]) {
                        sh """
                        ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${publicIp} << 'EOF'
                        echo "Verifying media files on the server..."
                        ls -la /home/ubuntu/ecommerce-django-react/media/
                        EOF

                        echo "Uploading media files to remote server..."
                        scp -o StrictHostKeyChecking=no -i ${SSH_KEY} -r media/* ubuntu@${publicIp}:/home/ubuntu/ecommerce-django-react/media/

                        echo "Verifying uploaded media files on the server..."
                        ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${publicIp} << 'EOF'
                        ls -la /home/ubuntu/ecommerce-django-react/media/
                        EOF
                        """
                    }
                }
            }
        }
    }
}
