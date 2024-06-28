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

stage('Deploy to Ubuntu') {
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

        stage('Configure Nginx') {
            steps {
                script {
                    withCredentials([sshUserPrivateKey(credentialsId: 'tesi_aws', keyFileVariable: 'SSH_KEY')]) {
                sh '''
                echo "Configuring Nginx on the server..."
                scp -o StrictHostKeyChecking=no -i ${SSH_KEY} config/nginx.conf ubuntu@${MY_UBUNTU_IP}:/home/ubuntu/ecommerce-django-react/nginx.conf
                ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${MY_UBUNTU_IP} << 'EOF'
                set -e

                # Clean up /etc/apt/sources.list and /etc/apt/sources.list.d/
                sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup
                sudo tee /etc/apt/sources.list <<EOL
deb http://archive.ubuntu.com/ubuntu/ noble main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ noble-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ noble-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ noble-security main restricted universe multiverse
EOL
                if [ -d /etc/apt/sources.list.d/ ]; then
                    sudo rm /etc/apt/sources.list.d/*
                fi

                # Update and upgrade all packages
                sudo apt-get update
                sudo apt-get upgrade -y
                sudo apt-get dist-upgrade -y

                # Fix broken packages
                sudo apt-get --fix-broken install
                sudo dpkg --configure -a

                # Unhold any held packages
                sudo apt-mark unhold libcrypt1 libcrypt-dev libssl-dev systemd-sysv libpam-runtime libpam-modules grub-efi-amd64-signed grub2-common mokutil

                # Remove and reinstall necessary libraries and Nginx
                sudo apt-get remove --purge nginx libcrypt1 libcrypt-dev libssl-dev
                sudo apt-get install -y nginx libcrypt1 libcrypt-dev libssl-dev

                # Check File System Type
                df -Th /usr /lib /lib/x86_64-linux-gnu

                # Check Library Path and Permissions
                sudo find / -iname "libcrypt.so*"

                # Verify library architecture
                file /usr/lib/libcrypt.so.1
                file /lib/x86_64-linux-gnu/libcrypt.so.1

                # Create symbolic link for libcrypt.so.1 if not exists
                sudo ln -sf /lib/x86_64-linux-gnu/libcrypt.so.1 /usr/lib/libcrypt.so.1

                # Ensure the symbolic link has correct permissions
                sudo chmod 755 /lib/x86_64-linux-gnu/libcrypt.so.1
                sudo chmod 755 /usr/lib/libcrypt.so.1
                sudo chown root:root /lib/x86_64-linux-gnu/libcrypt.so.1
                sudo chown root:root /usr/lib/libcrypt.so.1

                # Clean up /etc/ld.so.conf and included files
                sudo tee /etc/ld.so.conf <<EOL
/lib/x86_64-linux-gnu
/usr/lib
EOL
                sudo rm -f /etc/ld.so.conf.d/*

                # Rebuild library cache
                sudo ldconfig -v

                # Move and enable Nginx configuration
                sudo mv /home/ubuntu/ecommerce-django-react/nginx.conf /etc/nginx/sites-available/ecommerce-django-react
                sudo ln -sf /etc/nginx/sites-available/ecommerce-django-react /etc/nginx/sites-enabled/ecommerce-django-react

                echo "Testing Nginx configuration..."
                sudo nginx -t || (echo "Nginx configuration test failed" && exit 1)

                echo "Restarting Nginx..."
                sudo systemctl restart nginx

                # Ensure directory permissions
                sudo chmod 755 /home
                sudo chmod 755 /home/ubuntu
                sudo chmod 755 /home/ubuntu/ecommerce-django-react
                sudo chmod 755 /home/ubuntu/ecommerce-django-react/staticfiles

                # Check SELinux and AppArmor status
                sudo apparmor_status
                sudo setenforce 0

                # Adjust AppArmor profile for Nginx
                echo 'Creating AppArmor profile for Nginx...'
                sudo touch /etc/apparmor.d/usr.sbin.nginx
                echo -e '#include <tunables/global>\\n/usr/sbin/nginx {\\n  /home/ubuntu/ecommerce-django-react/staticfiles/** r,\\n}' | sudo tee /etc/apparmor.d/usr.sbin.nginx

                sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.nginx
EOF
                '''
                    }
                }
            }
        }
    }
}