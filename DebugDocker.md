docker-compose logs web
docker-compose exec web python manage.py collectstatic --noinput
ls -la /home/ubuntu/ecommerce-django-react/staticfiles/
ls -la /home/ubuntu/ecommerce-django-react/media/images/
ssh -i "C:\Users\sammo\.ssh\tesi-aws.pem" ubuntu@3.76.217.10


cd /home/ubuntu/ecommerce-django-react

sudo nano /etc/nginx/sites-available/ecommerce-django-react
sudo vim /etc/nginx/sites-available/ecommerce-django-react



Correct file generation inside the Docker container.
Correct file permissions.
Correct file transfer from the Docker container to the host.
Correct file transfer from the host to Jenkins.


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


        ssh -i /path/to/ssh_key ubuntu@your_server_ip
sudo chmod -R 777 /home/ubuntu/ecommerce-django-react
cd /home/ubuntu/ecommerce-django-react
docker-compose -f docker-compose.yml exec -T web sh -c "pytest tests/api/ --junitxml=/app/report.xml | tee /app/test_output.log"
docker-compose -f docker-compose.yml exec -T web ls -l /app
docker cp web:/app/report.html /home/ubuntu/ecommerce-django-react/report.html
docker cp web:/app/report.xml /home/ubuntu/ecommerce-django-react/report.xml
docker cp web:/app/test_output.log /home/ubuntu/ecommerce-django-react/test_output.log





        stage('Clean Environment and Run Tests in Docker') {
            steps {
                script {
                    withCredentials([string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                                     string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'),
                                     sshUserPrivateKey(credentialsId: 'tesi_aws', keyFileVariable: 'SSH_KEY')]) {
                        sh '''
                        echo "Cleaning environment and running tests in Docker container..."
                        ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${MY_UBUNTU_IP} << 'EOF'
                        set -e
                        # Clean Docker environment
                        docker-compose -f /home/ubuntu/ecommerce-django-react/docker-compose.yml down --volumes
                        docker system prune -af --volumes
                        sudo rm -rf /home/ubuntu/ecommerce-django-react/report.html /home/ubuntu/ecommerce-django-react/report.xml /home/ubuntu/ecommerce-django-react/test_output.log
                        
                        # Run tests in Docker container
                        sudo chmod -R 777 /home/ubuntu/ecommerce-django-react
                        docker-compose -f /home/ubuntu/ecommerce-django-react/docker-compose.yml up -d
                        docker-compose -f /home/ubuntu/ecommerce-django-react/docker-compose.yml exec -T web sh -c "
                            if ! pip show pytest > /dev/null 2>&1; then
                                pip install pytest pytest-html
                            fi
                            pytest tests/api/ --junitxml=/app/report.xml | tee /app/test_output.log
                        "
                        docker-compose -f /home/ubuntu/ecommerce-django-react/docker-compose.yml exec -T web ls -l /app
                        docker cp web:/app/report.html /home/ubuntu/ecommerce-django-react/report.html
                        docker cp web:/app/report.xml /home/ubuntu/ecommerce-django-react/report.xml
                        docker cp web:/app/test_output.log /home/ubuntu/ecommerce-django-react/test_output.log
EOF
                        '''
                        sh '''
                        scp -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${MY_UBUNTU_IP}:/home/ubuntu/ecommerce-django-react/report.html ./
                        scp -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${MY_UBUNTU_IP}:/home/ubuntu/ecommerce-django-react/report.xml ./
                        scp -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${MY_UBUNTU_IP}:/home/ubuntu/ecommerce-django-react/test_output.log ./
                        '''
                    }
                }
            }
        }

        stage('Publish Test Report') {
            steps {
                script {
                    publishHTML(target: [
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: '.',
                        reportFiles: 'report.html',
                        reportName: 'Test Report',
                        reportTitles: 'Test Report'
                    ])
                }
            }
        }


  stage('Run Tests in Docker') {
    steps {
        script {
            withCredentials([string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                             string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'),
                             sshUserPrivateKey(credentialsId: 'tesi_aws', keyFileVariable: 'SSH_KEY')]) {
                try {
                    sh '''
                    echo "Running tests in Docker container..."
                    ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${MY_UBUNTU_IP} << 'EOF'
                    set -e
                    # Clean previous report files
                    sudo rm -rf /home/ubuntu/ecommerce-django-react/report.html

                    # Run tests inside the Docker container
                    docker-compose -f /home/ubuntu/ecommerce-django-react/docker-compose.yml exec -T web sh -c "
                        if ! pip show pytest > /dev/null 2>&1; then
                            pip install pytest pytest-html
                        fi
                        pytest --html=/app/report.html || true
                    "

                    # Verify the report file was generated
                    docker-compose -f /home/ubuntu/ecommerce-django-react/docker-compose.yml exec -T web ls -l /app/report.html

                    # Copy the generated report back to the host
                    docker cp \$(docker-compose -f /home/ubuntu/ecommerce-django-react/docker-compose.yml ps -q web):/app/report.html /home/ubuntu/ecommerce-django-react/report.html || true

                    # List the contents of the directory to verify the report is there
                    ls -l /home/ubuntu/ecommerce-django-react
EOF
                    '''
                    sh '''
                    scp -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${MY_UBUNTU_IP}:/home/ubuntu/ecommerce-django-react/report.html ./
                    '''
                } catch (Exception e) {
                    currentBuild.result = 'UNSTABLE'
                    echo "Tests failed but continuing to publish report: ${e.message}"
                }
            }
        }
    }
}

stage('Publish Report') {
    steps {
        publishHTML(target: [
            allowMissing: false,
            alwaysLinkToLastBuild: true,
            keepAll: true,
            reportDir: '.',
            reportFiles: 'report.html',
            reportName: 'Test Report',
            reportTitles: 'Test Report'
        ])
    }
}




        DOCKER_IMAGE = 'ecommerce-test-image'
        CONTAINER_NAME = 'ecommerce-test-container'


tests with container :

        stage('Run Tests in Docker') {
            steps {
                script {
                    sh '''
                    echo "Building Docker image..."
                    docker build -t ${DOCKER_IMAGE} -f Dockerfile .

                    echo "Removing existing container if it exists..."
                    docker rm -f ${CONTAINER_NAME} || true

                    echo "Running tests in Docker container..."
                    docker run --name ${CONTAINER_NAME} -d ${DOCKER_IMAGE}

                    docker exec ${CONTAINER_NAME} sh -c "
                        pytest tests/api/ --junitxml=/app/report.xml --html-report=/app/report.html --self-contained-html | tee /app/test_output.log
                    "

                    echo "Copying test reports from Docker container to Jenkins workspace..."
                    docker cp ${CONTAINER_NAME}:/app/report.html ./report.html
                    docker cp ${CONTAINER_NAME}:/app/report.xml ./report.xml
                    docker cp ${CONTAINER_NAME}:/app/test_output.log ./test_output.log

                    echo "Listing copied files..."
                    ls -l report.html report.xml test_output.log

                    echo "Stopping and removing Docker container..."
                    docker stop ${CONTAINER_NAME}
                    docker rm ${CONTAINER_NAME}
                    '''
                }
            }
        }

        stage('Publish Test Report') {
            steps {
                script {
                    publishHTML(target: [
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: '.',
                        reportFiles: 'report.html',
                        reportName: 'Test Report',
                        reportTitles: 'Test Report'
                    ])
                }
            }
        }
