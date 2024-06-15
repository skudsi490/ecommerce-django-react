pipeline {
    agent any
    environment {
        REPO_URL = 'https://github.com/gagishmagi/ecommerce-django-react'
        DOCKER_IMAGE_BACKEND = 'your_dockerhub_username/ecommerce-django-react-backend'
        DOCKER_IMAGE_FRONTEND = 'your_dockerhub_username/ecommerce-django-react-frontend'
        S3_BUCKET = 'jenkins-artifacts-bucket-123456'
        JIRA_URL = 'https://ecommerce-django-react.atlassian.net/'
        JIRA_USER = 'skudsi490@gmail.com'
        JIRA_API_TOKEN = credentials('JIRA_API_TOKEN') 
    }

    stages {
        stage('Checkout') {
            steps {
                git url: "${REPO_URL}"
            }
        }
        stage('Build Backend') {
            steps {
                script {
                    docker.build("${DOCKER_IMAGE_BACKEND}:latest", "./backend")
                }
            }
        }
        stage('Build Frontend') {
            steps {
                script {
                    docker.build("${DOCKER_IMAGE_FRONTEND}:latest", "./frontend")
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
                    success()
                }
            }
            steps {
                script {
                    docker.withRegistry('', 'dockerhub') {
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
                    success()
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
                def jiraIssue = jiraNewIssue site: 'your-jira-site',
                                             issue: [
                                                 fields: [
                                                     project: [key: 'YOUR_PROJECT_KEY'],
                                                     summary: "Build failure in Jenkins job ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                                                     description: errorReport,
                                                     issuetype: [name: 'Bug']
                                                 ]
                                             ]
                echo "JIRA issue created: ${jiraIssue.key}"
            }
        }
    }
}