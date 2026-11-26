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
                    flake8 . --exclude=venv,.git --exit-zero
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
                bat '''
                    docker build -t %DOCKER_IMAGE_NAME%:%BUILD_NUMBER% .
                    docker tag %DOCKER_IMAGE_NAME%:%BUILD_NUMBER% %DOCKER_IMAGE_NAME%:latest
                '''
            }
        }

        stage('Security Scan') {
            steps {
                bat '''
                    trivy image --exit-code 0 --severity HIGH,CRITICAL %DOCKER_IMAGE_NAME%:%BUILD_NUMBER%
                '''
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
                    bat '''
                        set DOCKER_CONFIG=%WORKSPACE%\\.docker

                        if not exist "%DOCKER_CONFIG%" mkdir "%DOCKER_CONFIG%"

                        powershell -NoProfile -Command "$auth=[Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($env:DOCKER_USER + ':' + $env:DOCKER_PASS)); $json='{\\\"auths\\\":{\\\"https://index.docker.io/v1/\\\":{\\\"auth\\\":\\\"' + $auth + '\\\"}}}'; Set-Content -Path ($env:DOCKER_CONFIG + '\\config.json') -Value $json -Encoding ascii"

                        docker push %DOCKER_IMAGE_NAME%:%BUILD_NUMBER%
                        docker push %DOCKER_IMAGE_NAME%:latest

                        del /f /q "%DOCKER_CONFIG%\\config.json"
                    '''
                }
            }
        }

        stage('Terraform Init') {
            steps {
                withCredentials([
                    [
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-creds'
                    ]
                ]) {
                    bat '''
                        cd terraform
                        terraform init -input=false
                    '''
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                bat '''
                    cd terraform
                    terraform validate
                '''
            }
        }

        stage('Terraform Plan') {
            steps {
                withCredentials([
                    [
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-creds'
                    ]
                ]) {
                    bat '''
                        cd terraform
                        terraform plan -input=false -out=tfplan
                    '''
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                withCredentials([
                    [
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-creds'
                    ]
                ]) {
                    bat '''
                        cd terraform
                        terraform apply -input=false -auto-approve tfplan
                    '''
                }
            }
        }

        stage('Deploy') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'cicd-key',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    bat '''
                        cd terraform

                        for /f "delims=" %%i in ('terraform output -raw instance_public_ip') do set EC2_IP=%%i

                        ssh -o StrictHostKeyChecking=no -i "%SSH_KEY%" %SSH_USER%@%EC2_IP% "docker pull %DOCKER_IMAGE_NAME%:latest && docker stop cicd-demo-app || true && docker rm cicd-demo-app || true && docker run -d --name cicd-demo-app -p 80:5000 %DOCKER_IMAGE_NAME%:latest"
                    '''
                }
            }
        }

        stage('Health Check') {
            steps {
                bat '''
                    cd terraform

                    for /f "delims=" %%i in ('terraform output -raw instance_public_ip') do set EC2_IP=%%i

                    powershell -NoProfile -Command "$response=Invoke-WebRequest -Uri ('http://' + $env:EC2_IP) -UseBasicParsing -TimeoutSec 30; if ($response.StatusCode -eq 200) { Write-Host 'Application is UP' } else { exit 1 }"
                '''
            }
        }
    }

    post {
        success {
            echo 'CI/CD Pipeline completed successfully!'
        }

        failure {
            echo 'CI/CD Pipeline failed!'
        }

        always {
            echo "Build Number: ${BUILD_NUMBER}"
            echo "Docker Image: ${DOCKER_IMAGE_NAME}:${BUILD_NUMBER}"
        }
    }
}
