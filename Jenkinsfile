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
        AWS_STORAGE_BUCKET_NAME = credentials('aws-storage-bucket-name')
        DJANGO_SETTINGS_MODULE = 'backend.settings'
        PYTHONPATH = '/app:/app/backend:/app/base'
        POSTGRES_DB = 'ecommerce'
        POSTGRES_USER = 'ecommerceuser'
        POSTGRES_PASSWORD = 'ecommercedbpassword'
        POSTGRES_HOST = 'db'
        REACT_APP_BACKEND_URL = 'http://3.67.70.116:8000'
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
                sudo yum clean all || true
                sudo yum autoremove -y || true
                sudo rm -rf /var/lib/docker/tmp/*
                sudo rm -rf /var/cache/yum

                if ! [ -x "$(command -v unzip)" ]; then
                    echo "Unzip not found, installing..."
                    sudo yum update -y
                    sudo yum install -y unzip
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

        stage('Install Docker Compose') {
            steps {
                sh '''
                if ! [ -x "$(command -v docker-compose)" ]; then
                  echo "Docker Compose not found, installing..."
                  sudo yum update -y
                  sudo yum install -y libxcrypt-compat
                  sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                  sudo chmod +x /usr/local/bin/docker-compose
                else
                  echo "Docker Compose is already installed."
                fi
                '''
            }
        }

        stage('Verify libcrypt.so.1') {
            steps {
                sh '''
                echo "Verifying libcrypt.so.1..."
                if [ ! -f /usr/lib64/libcrypt.so.1 ]; then
                  echo "libcrypt.so.1 not found, installing libxcrypt-compat..."
                  sudo yum install -y libxcrypt-compat
                else
                  echo "libcrypt.so.1 found."
                fi
                '''
            }
        }

        stage('Build and Push Docker Image') {
            steps {
                script {
                    sh 'docker-compose build --no-cache'
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

        stage('Verify django-storages Installation') {
            steps {
                script {
                    sh '''
                    docker run --rm ${DOCKER_IMAGE_WEB}:latest python -c "import storages; print('django-storages is installed')"
                    '''
                }
            }
        }

        stage('Deploy to Ubuntu') {
            steps {
                script {
                    withCredentials([string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                                     string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'),
                                     string(credentialsId: 'aws-storage-bucket-name', variable: 'AWS_STORAGE_BUCKET_NAME'),
                                     sshUserPrivateKey(credentialsId: 'tesi_aws', keyFileVariable: 'SSH_KEY')]) {
                        sh '''
                        export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                        export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                        export AWS_STORAGE_BUCKET_NAME=${AWS_STORAGE_BUCKET_NAME}
                        aws s3 cp s3://${AWS_STORAGE_BUCKET_NAME}/terraform/state/terraform.tfstate terraform.tfstate
                        unset AWS_ACCESS_KEY_ID
                        unset AWS_SECRET_ACCESS_KEY
                        unset AWS_STORAGE_BUCKET_NAME
                        '''
                        def terraformState = readFile 'terraform.tfstate'
                        def ubuntuIp = sh(script: "jq -r '.resources[] | select(.type==\"aws_instance\" and .name==\"my_ubuntu\").instances[0].attributes.public_ip' terraform.tfstate", returnStdout: true).trim()
                        
                        if (ubuntuIp) {
                            env.MY_UBUNTU_IP = ubuntuIp
                            sh '''
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${MY_UBUNTU_IP} << 'EOF'
                                set -e
                                echo "Checking disk space and directory permissions..."
                                df -h
                                sudo rm -rf /home/ubuntu/ecommerce-django-react/
                                mkdir -p /home/ubuntu/ecommerce-django-react/
                                chmod 755 /home/ubuntu/ecommerce-django-react/
EOF
                            '''
                            echo "Uploading files to remote server..."
                            sh '''
                            scp -o StrictHostKeyChecking=no -i ${SSH_KEY} docker-compose.yml ubuntu@${MY_UBUNTU_IP}:/home/ubuntu/ecommerce-django-react/
                            scp -o StrictHostKeyChecking=no -i ${SSH_KEY} -r Dockerfile entrypoint.sh backend base frontend manage.py requirements.txt static media data_dump.json pytest.ini ubuntu@${MY_UBUNTU_IP}:/home/ubuntu/ecommerce-django-react/
                            '''
                            sh '''
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${MY_UBUNTU_IP} << 'EOF'
                            set -e
                            if ! [ -x "$(command -v docker)" ]; then
                              echo "Docker not found, installing..."
                              sudo apt update
                              sudo apt install docker.io -y
                              sudo systemctl start docker
                              sudo systemctl enable docker
                              sudo usermod -aG docker ubuntu
                            fi
                            docker network create app-network || true
                            docker-compose -f /home/ubuntu/ecommerce-django-react/docker-compose.yml down --remove-orphans
                            docker network prune -f
                            docker-compose -f /home/ubuntu/ecommerce-django-react/docker-compose.yml up -d
EOF
                            '''
                            echo "Running Django migrations and loading data..."
                            sh '''
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${MY_UBUNTU_IP} << 'EOF'
                            set -e
                            docker-compose -f /home/ubuntu/ecommerce-django-react/docker-compose.yml exec -T web python manage.py makemigrations
                            docker-compose -f /home/ubuntu/ecommerce-django-react/docker-compose.yml exec -T web python manage.py migrate
                            docker-compose -f /home/ubuntu/ecommerce-django-react/docker-compose.yml exec -T web python manage.py loaddata /app/data_dump.json
EOF
                            '''
                        } else {
                            error("Missing ubuntu_ip in terraform state.")
                        }
                    }
                }
            }
        }

        stage('Verify and Upload Media Files') {
            steps {
                script {
                    withCredentials([sshUserPrivateKey(credentialsId: 'tesi_aws', keyFileVariable: 'SSH_KEY')]) {
                        sh '''
                        echo "Verifying media files on the server..."
                        ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${MY_UBUNTU_IP} << 'EOF'
                        set -e
                        if [ ! -d "/home/ubuntu/ecommerce-django-react/media/images" ]; then
                            echo "Creating media/images directory..."
                            mkdir -p /home/ubuntu/ecommerce-django-react/media/images
                            chmod 755 /home/ubuntu/ecommerce-django-react/media/images
                        fi
EOF
                        '''
                        def images = sh(script: "jq -r '.[] | select(.model==\"base.product\") | .fields.image' data_dump.json", returnStdout: true).trim().split('\n')
                        echo "Images to be verified and uploaded: ${images}"
                        for (image in images) {
                            def imagePath = "media/${image}".trim()
                            sh """
                            if [ ! -f "${imagePath}" ]; then
                                echo "Error: Local image file ${imagePath} not found."
                                exit 1
                            fi
                            """
                            sh """
                            scp -o StrictHostKeyChecking=no -i ${SSH_KEY} ${imagePath} ubuntu@${MY_UBUNTU_IP}:/home/ubuntu/ecommerce-django-react/${imagePath}
                            """
                            sh """
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${MY_UBUNTU_IP} << 'EOF'
                            if [ ! -f "/home/ubuntu/ecommerce-django-react/${imagePath}" ]; then
                                echo "Error: Failed to upload image ${imagePath}."
                                exit 1
                            fi
EOF
                            """
                        }
                    }
                }
            }
        }
    }
}
