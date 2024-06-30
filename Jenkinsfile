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
        S3_BUCKET = 'jenkins-artifacts-bucket-123456'
        DJANGO_SETTINGS_MODULE = 'backend.settings'
        PYTHONPATH = '/app:/app/backend:/app/base'
        POSTGRES_DB = 'ecommerce'
        POSTGRES_USER = 'ecommerceuser'
        POSTGRES_PASSWORD = 'ecommercedbpassword'
        POSTGRES_HOST = 'db'
        REACT_APP_BACKEND_URL = 'http://18.194.20.42:8000'
        SLACK_CHANNEL = '#jenkins-builds'
        SLACK_USERNAME = 'Jenkins'
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
                sudo rm -rf /var/lib/yum/yumdb/*
                sudo rm -rf /var/lib/yum/history/*

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

        // stage('Build Locally') {
        //     steps {
        //         sh '''
        //         echo "Installing dependencies using yum..."
        //         sudo yum update -y
        //         sudo yum install -y python3 python3-pip nodejs npm

        //         echo "Setting up virtual environment and installing dependencies..."
        //         python3 -m venv .venv
        //         . .venv/bin/activate
        //         pip install --upgrade pip
        //         pip install -r requirements.txt

        //         echo "Building frontend..."
        //         cd frontend
        //         npm install
        //         npm run build
        //         cd ..

        //         echo "Running database migrations..."
        //         .venv/bin/python manage.py makemigrations
        //         .venv/bin/python manage.py migrate

        //         echo "Collecting static files..."
        //         .venv/bin/python manage.py collectstatic --noinput

        //         echo "Starting Django development server..."
        //         nohup .venv/bin/python manage.py runserver 0.0.0.0:8000 &
        //         '''
        //     }
        // }

        // stage('Test Locally') {
        //     steps {
        //         script {
        //             catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
        //                 sh '''
        //                 echo "Activating virtual environment..."
        //                 . .venv/bin/activate

        //                 echo "Running tests..."
        //                 pytest --html-report=./report.html
        //                 '''
        //             }
        //         }
        //     }
        // }

        // stage('Publish Report') {
        //     steps {
        //         publishHTML(target: [
        //             allowMissing: false,
        //             alwaysLinkToLastBuild: true,
        //             keepAll: true,
        //             reportDir: '.',
        //             reportFiles: 'report.html',
        //             reportName: 'Test Report',
        //             reportTitles: 'Test Report'
        //         ])
        //     }
        // }

        // stage('Test Docker Login') {
        //     when {
        //         expression { currentBuild.currentResult == 'SUCCESS' }
        //     }
        //     steps {
        //         script {
        //             retry(3) {
        //                 withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
        //                     sh 'echo $DOCKER_PASSWORD | docker login -u $DOCKER_USERNAME --password-stdin'
        //                 }
        //             }
        //         }
        //     }
        // }

        // stage('Build and Push Docker Image') {
        //     when {
        //         expression { currentBuild.currentResult == 'SUCCESS' }
        //     }
        //     steps {
        //         script {
        //             docker.build("${DOCKER_IMAGE_WEB}:latest", "--build-arg REACT_APP_BACKEND_URL=${REACT_APP_BACKEND_URL} .")
        //         }
        //     }
        // }

        // stage('Push Docker Image') {
        //     when {
        //         expression { currentBuild.currentResult == 'SUCCESS' }
        //     }
        //     steps {
        //         script {
        //             docker.withRegistry('https://index.docker.io/v1/', 'dockerhub') {
        //                 docker.image("${DOCKER_IMAGE_WEB}:latest").push('latest')
        //             }
        //         }
        //     }
        // }

        stage('Deploy to Ubuntu') {
            when {
                expression { currentBuild.currentResult == 'SUCCESS' }
            }
            steps {
                script {
                    withCredentials([string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                                    string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'),
                                    sshUserPrivateKey(credentialsId: 'tesi_aws', keyFileVariable: 'SSH_KEY')]) {
                        sh '''
                        export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                        export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                        aws s3 cp s3://${S3_BUCKET}/terraform/state/terraform.tfstate terraform.tfstate
                        unset AWS_ACCESS_KEY_ID
                        unset AWS_SECRET_ACCESS_KEY
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
                                sudo rm -rf /var/lib/postgresql/data
                                mkdir -p /home/ubuntu/ecommerce-django-react/
                                chmod 755 /home/ubuntu/ecommerce-django-react/
EOF
                            '''
                            echo "Uploading files to remote server..."
                            sh '''
                            scp -o StrictHostKeyChecking=no -i ${SSH_KEY} docker-compose.yml ubuntu@${MY_UBUNTU_IP}:/home/ubuntu/ecommerce-django-react/
                            scp -o StrictHostKeyChecking=no -i ${SSH_KEY} -r Dockerfile entrypoint.sh backend base frontend manage.py requirements.txt static media data_dump.json pytest.ini config/nginx.conf tests ubuntu@${MY_UBUNTU_IP}:/home/ubuntu/ecommerce-django-react/
                            '''
                            echo "Pulling Docker image from DockerHub..."
                            script {
                                docker.image("${DOCKER_IMAGE_WEB}:latest").pull()
                            }
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
                            if ! [ -x "$(command -v docker-compose)" ]; then
                            echo "Docker Compose not found, installing..."
                            sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-\$(uname -s)-\$(uname -m)" -o /usr/local/bin/docker-compose
                            sudo chmod +x /usr/local/bin/docker-compose
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
                            docker-compose -f /home/ubuntu/ecommerce-django-react/docker-compose.yml exec -T web sh -c "
                                mkdir -p /app/staticfiles && chmod -R 755 /app/staticfiles &&
                                python manage.py makemigrations &&
                                python manage.py migrate &&
                                python manage.py loaddata /tmp/data_dump.json &&
                                python manage.py collectstatic --noinput
                            "
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

    post {
        failure {
            script {
                def buildStatus = currentBuild.currentResult ?: 'FAILURE'
                def message = "The build status is ${buildStatus}, on project ${env.JOB_NAME}. Find the test report here: ${env.BUILD_URL}/Test_20Report/"

                // Slack notification
                slackSend channel: "${SLACK_CHANNEL}",
                          username: "${SLACK_USERNAME}",
                          message: message

                // Email notification
                emailext body: """The build status is ${buildStatus}, on project ${env.JOB_NAME} find test report in this url: ${BUILD_URL}/Test_20Report/""",
                         subject: """You got a failed build/job ${env.JOB_NAME} - ${env.BUILD_NUMBER} from Jenkins""",
                         to: 'skudsi499@gmail.com'
            }
        }
    }
}
