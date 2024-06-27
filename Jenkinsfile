pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub')
        AWS_ACCESS_KEY_ID = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
        AWS_STORAGE_BUCKET_NAME = 'your-bucket-name'
        SSH_KEY = credentials('ssh-key')
    }

    stages {
        stage('Pre-Cleanup') {
            steps {
                sh '''
                echo 'Disk usage before cleanup:'
                df -h
                echo 'Cleaning up workspace and Docker resources'
                docker system prune -af --volumes
                sudo rm -rf /home/ec2-user/workspace/Django-CICD-V8/*
                sudo yum clean all
                sudo yum autoremove -y
                sudo rm -rf /var/lib/docker/tmp/*
                sudo rm -rf /var/cache/yum
                '''
            }
        }
        stage('Checkout') {
            steps {
                git 'https://github.com/skudsi490/ecommerce-django-react.git'
            }
        }
        stage('Verify Required Files') {
            steps {
                sh '''
                echo 'Contents of project root directory:'
                ls -la
                '''
            }
        }
        stage('Test Docker Login') {
            steps {
                script {
                    retry(3) {
                        withCredentials([string(credentialsId: 'dockerhub', variable: 'DOCKER_PASSWORD')]) {
                            sh 'echo $DOCKER_PASSWORD | docker login -u skudsi --password-stdin'
                        }
                    }
                }
            }
        }
        stage('Install Docker Compose') {
            steps {
                sh '''
                if ! command -v docker-compose &> /dev/null; then
                    echo "Docker Compose could not be found. Installing..."
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
                echo 'Verifying libcrypt.so.1...'
                if [ ! -f /usr/lib64/libcrypt.so.1 ]; then
                    echo 'libcrypt.so.1 not found. Installing...'
                    sudo ln -s /lib/x86_64-linux-gnu/libcrypt.so.1 /usr/lib64/libcrypt.so.1
                else
                    echo 'libcrypt.so.1 found.'
                fi
                '''
            }
        }
        stage('Build and Push Docker Image') {
            steps {
                script {
                    withEnv(["DOCKER_BUILDKIT=1"]) {
                        sh 'docker-compose build --no-cache'
                    }
                }
            }
        }
        stage('Push Docker Image') {
            steps {
                script {
                    docker.withRegistry('https://index.docker.io/v1/', 'dockerhub') {
                        sh 'docker tag skudsi/ecommerce-django-react-web:latest index.docker.io/skudsi/ecommerce-django-react-web:latest'
                        sh 'docker push index.docker.io/skudsi/ecommerce-django-react-web:latest'
                    }
                }
            }
        }
        stage('Deploy to Ubuntu') {
            steps {
                script {
                    withCredentials([string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'), 
                                     string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'), 
                                     string(credentialsId: 'ssh-key', variable: 'SSH_KEY')]) {
                        sh '''
                        export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                        export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                        export AWS_STORAGE_BUCKET_NAME=$AWS_STORAGE_BUCKET_NAME
                        aws s3 cp s3://$AWS_STORAGE_BUCKET_NAME/terraform/state/terraform.tfstate terraform.tfstate
                        IP=$(jq -r '.resources[] | select(.type=="aws_instance" and .name=="my_ubuntu").instances[0].attributes.public_ip' terraform.tfstate)
                        echo $IP

                        ssh -o StrictHostKeyChecking=no -i $SSH_KEY ubuntu@$IP << 'EOF'
                        echo "Checking disk space and directory permissions..."
                        df -h
                        EOF

                        echo "Uploading files to remote server..."
                        scp -o StrictHostKeyChecking=no -i $SSH_KEY docker-compose.yml ubuntu@$IP:/home/ubuntu/ecommerce-django-react/
                        scp -o StrictHostKeyChecking=no -i $SSH_KEY -r Dockerfile entrypoint.sh backend base frontend manage.py requirements.txt static media data_dump.json pytest.ini ubuntu@$IP:/home/ubuntu/ecommerce-django-react/

                        ssh -o StrictHostKeyChecking=no -i $SSH_KEY ubuntu@$IP << 'EOF'
                        docker-compose down
                        docker-compose up -d --build
                        EOF
                        '''
                    }
                }
            }
        }
        stage('Run Migrations') {
            steps {
                script {
                    withCredentials([string(credentialsId: 'ssh-key', variable: 'SSH_KEY')]) {
                        sh '''
                        IP=$(jq -r '.resources[] | select(.type=="aws_instance" and .name=="my_ubuntu").instances[0].attributes.public_ip' terraform.tfstate)
                        ssh -o StrictHostKeyChecking=no -i $SSH_KEY ubuntu@$IP << 'EOF'
                        cd /home/ubuntu/ecommerce-django-react/
                        docker-compose exec web python manage.py migrate
                        docker-compose exec web python manage.py loaddata data_dump.json
                        EOF
                        '''
                    }
                }
            }
        }
    }
    post {
        always {
            echo 'Pipeline completed'
        }
        success {
            echo 'Pipeline succeeded'
        }
        failure {
            echo 'Pipeline failed'
        }
    }
}
