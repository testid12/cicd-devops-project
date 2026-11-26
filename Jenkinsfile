pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '15'))
        timeout(time: 45, unit: 'MINUTES')
    }

    environment {

        DOCKERHUB_USERNAME = 'princeydv77'
        DOCKER_IMAGE_NAME  = "${DOCKERHUB_USERNAME}/cicd-demo-app"

        AWS_REGION         = 'ap-south-1'
        EC2_SSH_USER       = 'ubuntu'

        DOCKER_CREDS = credentials('dockerhub-creds')
    }

    stages {

        stage('Checkout') {
            steps {
                echo "==> Cloning repository"

                checkout scm

                script {
                    env.GIT_COMMIT_SHORT = bat(
                        script: '@git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()

                    env.IMAGE_TAG =
                        "${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"

                    echo "Git Commit: ${env.GIT_COMMIT_SHORT}"
                    echo "Docker Image Tag: ${env.IMAGE_TAG}"
                }
            }
        }


        stage('Build') {
            steps {
                echo "==> Installing dependencies and building the app"

                bat '''
                    python --version

                    if not exist .venv (
                        python -m venv .venv
                    )

                    .venv\\Scripts\\python.exe -m pip install --upgrade pip

                    .venv\\Scripts\\python.exe -m pip install -r app\\requirements-dev.txt
                '''
            }
        }


        stage('Test') {
            steps {
                echo "==> Running automated tests"

                bat '''
                    .venv\\Scripts\\python.exe -m pytest app\\tests ^
                        --junitxml=test-results.xml ^
                        --cov=app ^
                        --cov-report=xml
                '''
            }

            post {
                always {
                    junit(
                        testResults: 'test-results.xml',
                        allowEmptyResults: true
                    )
                }
            }
        }


        stage('Code Quality') {
            steps {

                echo "==> Running SonarQube analysis"

                script {

                    def scannerHome = tool 'SonarScanner'

                    echo "SonarScanner location: ${scannerHome}"

                    withSonarQubeEnv('SonarQube') {

                        withCredentials([
                            string(
                                credentialsId: 'sonarqube-token',
                                variable: 'SONAR_TOKEN'
                            )
                        ]) {

                            bat """
                                echo.
                                echo ===============================================
                                echo Running Flake8
                                echo ===============================================

                                .venv\\\\Scripts\\\\python.exe -m pip install flake8

                                .venv\\\\Scripts\\\\python.exe -m flake8 app ^
                                    --max-line-length=120 ^
                                    --exit-zero ^
                                    > flake8-report.txt

                                echo.
                                echo ===============================================
                                echo Running SonarQube Scanner
                                echo ===============================================

                                "${scannerHome}\\\\bin\\\\sonar-scanner.bat" ^
                                    -Dsonar.projectKey=cicd-devops-project ^
                                    -Dsonar.sources=app ^
                                    -Dsonar.python.version=3.11 ^
                                    -Dsonar.python.coverage.reportPaths=coverage.xml ^
                                    -Dsonar.token=%SONAR_TOKEN%
                            """
                        }
                    }
                }
            }
        }


        stage('Docker Build') {
            steps {
                echo "==> Building Docker image"

                bat '''
                    docker --version

                    docker build ^
                        --build-arg APP_VERSION=%IMAGE_TAG% ^
                        --build-arg BUILD_NUMBER=%BUILD_NUMBER% ^
                        --build-arg GIT_COMMIT=%GIT_COMMIT_SHORT% ^
                        -t %DOCKER_IMAGE_NAME%:%IMAGE_TAG% ^
                        -t %DOCKER_IMAGE_NAME%:latest ^
                        .
                '''
            }
        }


        stage('Security Scan') {
            steps {
                echo "==> Scanning image with Trivy"

                bat '''
                    where trivy

                    if %ERRORLEVEL% NEQ 0 (
                        echo.
                        echo ERROR: Trivy is not installed or not available in PATH.
                        echo Install Trivy on the Jenkins Windows machine.
                        exit /b 1
                    )

                    trivy image ^
                        --severity HIGH,CRITICAL ^
                        --exit-code 0 ^
                        --format table ^
                        -o trivy-report.txt ^
                        %DOCKER_IMAGE_NAME%:%IMAGE_TAG%

                    type trivy-report.txt
                '''
            }
        }


        stage('Docker Push') {
            steps {
                echo "==> Pushing image to Docker Hub"

                bat '''
                    echo %DOCKER_CREDS_PSW% | docker login ^
                        -u %DOCKER_CREDS_USR% ^
                        --password-stdin

                    docker push %DOCKER_IMAGE_NAME%:%IMAGE_TAG%

                    docker push %DOCKER_IMAGE_NAME%:latest

                    docker logout
                '''
            }
        }


        stage('Terraform Init') {
            steps {

                dir('terraform') {

                    withCredentials([
                        [
                            $class: 'AmazonWebServicesCredentialsBinding',
                            credentialsId: 'aws-creds'
                        ]
                    ]) {

                        bat '''
                            terraform init -input=false
                        '''
                    }
                }
            }
        }


        stage('Terraform Validate') {
            steps {

                dir('terraform') {

                    bat '''
                        terraform validate
                    '''
                }
            }
        }


        stage('Terraform Plan') {
            steps {

                dir('terraform') {

                    withCredentials([
                        [
                            $class: 'AmazonWebServicesCredentialsBinding',
                            credentialsId: 'aws-creds'
                        ]
                    ]) {

                        bat '''
                            terraform plan ^
                                -input=false ^
                                -var="docker_image=%DOCKER_IMAGE_NAME%:%IMAGE_TAG%" ^
                                -out=tfplan
                        '''
                    }
                }
            }
        }


        stage('Terraform Apply') {
            steps {

                dir('terraform') {

                    withCredentials([
                        [
                            $class: 'AmazonWebServicesCredentialsBinding',
                            credentialsId: 'aws-creds'
                        ]
                    ]) {

                        bat '''
                            terraform apply ^
                                -input=false ^
                                -auto-approve ^
                                tfplan
                        '''

                        script {

                            env.EC2_PUBLIC_IP = bat(
                                script: '@terraform output -raw ec2_public_ip',
                                returnStdout: true
                            ).trim()

                            echo "EC2 Public IP: ${env.EC2_PUBLIC_IP}"
                        }
                    }
                }
            }
        }


        stage('Deploy') {
            steps {

                echo "==> Deploying new image to EC2 (${env.EC2_PUBLIC_IP})"

                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'ec2-ssh-key',
                        keyFileVariable: 'SSH_KEY'
                    )
                ]) {

                    bat '''
                        echo.
                        echo ===============================================
                        echo Copying deployment script to EC2
                        echo ===============================================

                        scp -i "%SSH_KEY%" ^
                            -o StrictHostKeyChecking=no ^
                            scripts\\deploy.sh ^
                            %EC2_SSH_USER%@%EC2_PUBLIC_IP%:/tmp/deploy.sh

                        echo.
                        echo ===============================================
                        echo Executing deployment script on EC2
                        echo ===============================================

                        ssh -i "%SSH_KEY%" ^
                            -o StrictHostKeyChecking=no ^
                            %EC2_SSH_USER%@%EC2_PUBLIC_IP% ^
                            "chmod +x /tmp/deploy.sh && /tmp/deploy.sh %DOCKER_IMAGE_NAME%:%IMAGE_TAG%"
                    '''
                }
            }
        }


        stage('Health Check') {
            steps {

                echo "==> Verifying application health"

                bat '''
                    echo.
                    echo ===============================================
                    echo Checking application health
                    echo ===============================================

                    curl.exe --fail ^
                        --max-time 30 ^
                        http://%EC2_PUBLIC_IP%:5000/health
                '''
            }
        }
    }


    post {

        success {
            echo "================================================="
            echo "Pipeline succeeded!"
            echo "App deployed at: http://${env.EC2_PUBLIC_IP}:5000"
            echo "================================================="
        }

        failure {
            echo "================================================="
            echo "Pipeline failed."
            echo "Check the stage logs above for details."
            echo "================================================="
        }

        always {

            echo "==> Cleaning workspace"

            bat '''
                where docker >nul 2>&1

                if %ERRORLEVEL% EQU 0 (
                    echo Docker found. Cleaning unused images...
                    docker image prune -f
                ) else (
                    echo Docker not found. Skipping Docker cleanup.
                )
            '''

            cleanWs()
        }
    }
}
