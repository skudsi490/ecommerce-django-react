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
        AWS_CREDENTIALS = credentials('aws-credentials')
        DJANGO_SETTINGS_MODULE = 'backend.settings'
        PYTHONPATH = '/app:/app/backend:/app/base'
        DOCKER_BUILDKIT = 1
    }

    stages {
        stage('Checkout') {
            steps {
                git url: "${REPO_URL}", branch: 'main'
            }
        }
        stage('Test Docker Login') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'dockerhub') {
                        sh 'docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD'
                        echo 'Docker login successful!'
                    }
                }
            }
        }
        stage('Clean Docker') {
            steps {
                sh '''
                echo "Cleaning up docker"
                docker system prune -af --volumes
                sudo apt-get clean
                sudo apt-get autoremove -y
                df -h
                '''
            }
        }
        stage('Build Backend') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'dockerhub') {
                        dir('backend') {
                            docker.build("${DOCKER_IMAGE_BACKEND}:latest", "--build-arg BUILDKIT_INLINE_CACHE=1 -f Dockerfile ..")
                            docker.image("${DOCKER_IMAGE_BACKEND}:latest").push('latest')
                        }
                    }
                }
            }
        }
        stage('Build Frontend') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'dockerhub') {
                        dir('frontend') {
                            docker.build("${DOCKER_IMAGE_FRONTEND}:latest", "--build-arg BUILDKIT_INLINE_CACHE=1 -f Dockerfile ..")
                            docker.image("${DOCKER_IMAGE_FRONTEND}:latest").push('latest')
                        }
                    }
                }
            }
        }
        stage('Install Docker Compose') {
            steps {
                sh '''
                if ! [ -x "$(command -v docker-compose)" ]; then
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
                    sudo apt-get update
                    sudo apt-get install -y software-properties-common
                    sudo add-apt-repository ppa:deadsnakes/ppa -y
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
                source venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt
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
                sudo apt-get install -y google-chrome-stable
                wget https://chromedriver.storage.googleapis.com/114.0.5735.90/chromedriver_linux64.zip
                unzip -o chromedriver_linux64.zip
                sudo mv chromedriver /usr/local/bin/
                sudo chmod +x /usr/local/bin/chromedriver
                '''
            }
        }
        stage('Unit Tests') {
            steps {
                sh '''
                mkdir -p backend/reports
                source venv/bin/activate && docker-compose run backend pytest --junitxml=/app/reports/unit_tests.xml
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
                source venv/bin/activate && docker-compose run backend pytest --junitxml=/app/reports/integration_tests.xml
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
                source venv/bin/activate && docker-compose -f docker-compose.e2e.yml run frontend pytest --junitxml=/app/reports/e2e_tests.xml
                '''
            }
            post {
                always {
                    junit 'frontend/reports/e2e_tests.xml'
                }
            }
        }
        stage('Push Docker Images') {
            when {
                branch 'main'
            }
            steps {
                script {
                    withDockerRegistry(credentialsId: 'dockerhub') {
                        docker.image("${DOCKER_IMAGE_BACKEND}:latest").push('latest')
                        docker.image("${DOCKER_IMAGE_FRONTEND}:latest").push('latest')
                    }
                }
            }
        }
        stage('Deploy') {
            when {
                allOf {
                    branch 'main'
                    expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
                }
            }
            steps {
                sh 'docker-compose up -d'
            }
        }
    } 

    post {
        failure {
            script {
                def errorReport = currentBuild.rawBuild.getLog(50).join("\n")
                emailext (
                    to: 'skudsi490@gmail.com',
                    subject: "Build failed in Jenkins: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    body: "Check Jenkins logs for details:\n\n${errorReport}"
                )
                // Create JIRA issue
                def jiraIssue = jiraNewIssue site: "${env.JIRA_SITE}",
                                             issue: [
                                                 fields: [
                                                     project: [key: "${env.JIRA_PROJECT_KEY}"],
                                                     summary: "Build failure in Jenkins job ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                                                     description: errorReport,
                                                     issuetype: [name: 'Bug']
                                                 ]
                                             ]
                echo "JIRA issue created: ${jiraIssue.key}"
            }
        }
        success {
            script {
                def successReport = currentBuild.rawBuild.getLog(50).join("\n")
                emailext (
                    to: 'skudsi490@gmail.com',
                    subject: "Build successful in Jenkins: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    body: "Build was successful:\n\n${successReport}"
                )
                // Create JIRA issue
                jiraSendIssue site: "${env.JIRA_SITE}", 
                              projectKey: "${env.JIRA_PROJECT_KEY}",
                              issueType: 'Task', 
                              summary: "Build success in Jenkins job ${env.JOB_NAME} #${env.BUILD_NUMBER}", 
                              description: "Build was successful. Check details at: ${env.BUILD_URL}"
                echo "JIRA issue notification sent."
            }
        }
    }
}

def withDockerCredentials(body) {
    withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
        body()
    }
}
