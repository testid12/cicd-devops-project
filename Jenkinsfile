pipeline {
    agent any

    environment {
        DOCKERHUB_USERNAME = 'princeydv77'
        DOCKER_IMAGE_NAME  = "${DOCKERHUB_USERNAME}/cicd-demo-app"
        AWS_REGION         = 'ap-south-1'
        EC2_SSH_USER       = 'ubuntu'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Setup Python') {
            steps {
                bat '''
                    python -m venv venv
                    call venv\\Scripts\\activate
                    python -m pip install --upgrade pip
                    pip install flask gunicorn pytest flake8 pytest-cov
                '''
            }
        }

        stage('Tests') {
            steps {
                bat '''
                    call venv\\Scripts\\activate
                    pytest -v
                '''
            }
        }

        stage('Flake8') {
            steps {
                bat '''
                    call venv\\Scripts\\activate
                    flake8 . --exclude=venv,.git
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonarqube') {
                    bat '''
                        call venv\\Scripts\\activate

                        sonar-scanner ^
                          -Dsonar.projectKey=cicd-devops-project ^
                          -Dsonar.sources=. ^
                          -Dsonar.host.url=%SONAR_HOST_URL% ^
                          -Dsonar.token=%SONAR_AUTH_TOKEN%
                    '''
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    def imageTag = "${env.BUILD_NUMBER}"

                    bat """
                        docker build -t ${DOCKER_IMAGE_NAME}:${imageTag} .
                        docker tag ${DOCKER_IMAGE_NAME}:${imageTag} ${DOCKER_IMAGE_NAME}:latest
                    """
                }
            }
        }

        stage('Security Scan') {
            steps {
                script {
                    def imageTag = "${env.BUILD_NUMBER}"

                    bat """
                        trivy image --exit-code 0 --severity HIGH,CRITICAL ${DOCKER_IMAGE_NAME}:${imageTag}
                    """
                }
            }
        }

        stage('Docker Push') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-test',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )
                ]) {
                    script {
                        def imageTag = "${env.BUILD_NUMBER}"

                        bat '''
                            set DOCKER_CONFIG=%WORKSPACE%\\.docker

                            if not exist "%DOCKER_CONFIG%" mkdir "%DOCKER_CONFIG%"

                            powers
