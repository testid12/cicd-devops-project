pipeline {
    agent any

    environment {
        DOCKER_IMAGE = 'princeydv77/cicd-demo-app'
        AWS_REGION = 'ap-south-1'
        EC2_USER = 'ubuntu'
        EC2_HOST = 'YOUR_EC2_PUBLIC_IP'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Setup Python') {
            steps {
                dir('app') {
                    bat '''
                        if exist venv rmdir /s /q venv
                        python -m venv venv
                        call venv\\Scripts\\activate
                        python -m pip install --upgrade pip
                        pip install -r requirements.txt
                        pip install flake8
                    '''
                }
            }
        }

        stage('Tests') {
            steps {
                dir('app') {
                    bat '''
                        call venv\\Scripts\\activate
                        pytest -v
                    '''
                }
            }
        }

        stage('Flake8') {
            steps {
                dir('app') {
                    bat '''
                        call venv\\Scripts\\activate
                        flake8 . --exclude=venv,.git --exit-zero
                    '''
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withCredentials([
                    string(
                        credentialsId: 'sonarqube-token',
                        variable: 'SONAR_TOKEN'
                    )
                ]) {
                    bat '''
                        sonar-scanner ^
                          -Dsonar.projectKey=cicd-devops-project ^
                          -Dsonar.sources=app ^
                          -Dsonar.host.url=http://localhost:9000 ^
                          -Dsonar.token=%SONAR_TOKEN%
                    '''
                }
            }
        }

        stage('Security Scan') {
            steps {
                bat '''
                    trivy fs . --exit-code 0 --severity HIGH,CRITICAL --skip-dirs app\\venv
                '''
            }
        }

        stage('Docker Build') {
            steps {
                bat '''
                    docker build -t %DOCKER_IMAGE%:%BUILD_NUMBER% .
                    docker tag %DOCKER_IMAGE%:%BUILD_NUMBER% %DOCKER_IMAGE%:latest
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

                        if exist "%DOCKER_CONFIG%" rmdir /s /q "%DOCKER_CONFIG%"
                        mkdir "%DOCKER_CONFIG%"

                        powershell -NoProfile -Command "$auth=[Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($env:DOCKER_USER + ':' + $env:DOCKER_PASS)); $json='{\\\"auths\\\":{\\\"https://index.docker.io/v1/\\\":{\\\"auth\\\":\\\"' + $auth + '\\\"}}}'; Set-Content -Path ($env:DOCKER_CONFIG + '\\config.json') -Value $json -Encoding ASCII"

                        docker push %DOCKER_IMAGE%:%BUILD_NUMBER%
                        docker push %DOCKER_IMAGE%:latest

                        del /f /q "%DOCKER_CONFIG%\\config.json"
                    '''
                }
            }
        }

        stage('Terraform Init') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-creds']
                ]) {
                    dir('terraform') {
                        bat '''
                            terraform init
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
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-creds']
                ]) {
                    dir('terraform') {
                        bat '''
                            terraform plan -var-file=terraform.tfvars
                        '''
                    }
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-creds']
                ]) {
                    dir('terraform') {
                        bat '''
                            terraform apply -auto-approve -var-file=terraform.tfvars
                        '''
                    }
                }
            }
        }

        stage('Deploy') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-test',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    ),
                    sshUserPrivateKey(
                        credentialsId: 'cicd-key',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    bat '''
                        echo Deploying application...

                        scp -i "%SSH_KEY%" -o StrictHostKeyChecking=no docker-compose.yml %SSH_USER%@%EC2_HOST%:/home/%SSH_USER%/

                        ssh -i "%SSH_KEY%" -o StrictHostKeyChecking=no %SSH_USER%@%EC2_HOST% "docker login -u %DOCKER_USER% -p %DOCKER_PASS% && docker pull %DOCKER_IMAGE%:latest && docker stop cicd-demo-app 2>nul || true && docker rm cicd-demo-app 2>nul || true && docker run -d --name cicd-demo-app -p 5000:5000 %DOCKER_IMAGE%:latest"
                    '''
                }
            }
        }

        stage('Health Check') {
            steps {
                bat '''
                    echo Waiting for application to start...
                    timeout /t 15 /nobreak

                    curl.exe -f http://%EC2_HOST%:5000/ || exit /b 1

                    echo Application is healthy!
                '''
            }
        }
    }

    post {
        success {
            echo '=========================================='
            echo ' CI/CD PIPELINE COMPLETED SUCCESSFULLY'
            echo '=========================================='
        }

        failure {
            echo '=========================================='
            echo ' CI/CD PIPELINE FAILED'
            echo ' Check the failed stage above'
            echo '=========================================='
        }
    }
}
