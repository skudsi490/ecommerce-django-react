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
        JIRA_PROJECT_KEY = 'PROJECT_KEY'
        DOCKERHUB_CREDENTIALS = credentials('dockerhub')
        AWS_CREDENTIALS = credentials('aws-credentials')
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
                    withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                        sh 'docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD'
                        echo 'Docker login successful!'
                    }
                }
            }
        }
        stage('Build Backend') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                        docker.withRegistry('https://index.docker.io/v1/', "${DOCKERHUB_CREDENTIALS}") {
                            def backendImage = docker.build("${DOCKER_IMAGE_BACKEND}:latest", "./backend")
                            backendImage.push('latest')
                        }
                    }
                }
            }
        }
        stage('Build Frontend') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                        docker.withRegistry('https://index.docker.io/v1/', "${DOCKERHUB_CREDENTIALS}") {
                            def frontendImage = docker.build("${DOCKER_IMAGE_FRONTEND}:latest", "./frontend")
                            frontendImage.push('latest')
                        }
                    }
                }
            }
        }
        stage('Unit Tests') {
            steps {
                sh 'docker-compose run backend pytest --junitxml=reports/unit_tests.xml'
            }
            post {
                always {
                    junit 'reports/unit_tests.xml'
                }
            }
        }
        stage('Integration Tests') {
            steps {
                sh 'docker-compose run backend pytest --junitxml=reports/integration_tests.xml'
            }
            post {
                always {
                    junit 'reports/integration_tests.xml'
                }
            }
        }
        stage('E2E Tests') {
            steps {
                sh 'docker-compose -f docker-compose.e2e.yml run frontend pytest --junitxml=reports/e2e_tests.xml'
            }
            post {
                always {
                    junit 'reports/e2e_tests.xml'
                }
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
                    withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                        docker.withRegistry('https://index.docker.io/v1/', "${DOCKERHUB_CREDENTIALS}") {
                            docker.image("${DOCKER_IMAGE_BACKEND}:latest").push('latest')
                            docker.image("${DOCKER_IMAGE_FRONTEND}:latest").push('latest')
                        }
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
                def errorReport = currentBuild.rawBuild.log.take(50).join("\n")
                emailext (
                    to: 'skudsi490@gmail.com',
                    subject: "Build failed in Jenkins: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    body: "Check Jenkins logs for details:\n\n${errorReport}"
                )
            }
        }
    }
}
