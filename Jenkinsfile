pipeline {
    agent any

    environment {
        DOCKER_IMAGE = 'princeydv77/cicd-demo-app'
        AWS_REGION   = 'ap-south-1'
        EC2_USER     = 'ubuntu'
        EC2_HOST     = 'YOUR_EC2_PUBLIC_IP'
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

        stage('SonarQube') {
            steps {
                dir('app') {
                    withCredentials([
                        string(
                            credentialsId: 'sonarqube-token',
                            variable: 'SONAR_TOKEN'
                        )
                    ]) {
                        bat '''
                            sonar-scanner ^
                              -Dsonar.projectKey=cicd-devops-project ^
                              -Dsonar.sources=. ^
                              -Dsonar.host.url=http://localhost:9000 ^
                              -Dsonar.token=%SONAR_TOKEN%
                        '''
                    }
                }
            }
        }

        stage('Security Scan') {
            steps {
                bat '''
                    trivy fs . --exit-code 0 --severity HIGH,CRITICAL
                '''
            }
        }

        stage('Docker Build') {
            steps {
                bat '''
                    docker build -t %DOCKER_IMAGE%:%BUILD_NUMBER% -t %DOCKER_IMAGE%:latest .
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

                        powershell -NoProfile -Command "$auth=[Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($env:DOCKER_USER + ':' + $env:DOCKER_PASS)); $json='{\\\"auths\\\":{\\\"https://index.docker.io/v1/\\\":{\\\"auth\\\":\\\"' + $auth + '\\\"}}}'; Set-Content -Path '%DOCKER_CONFIG%\\config.json' -Value $json"

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
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-creds']
                ]) {
                    dir('terraform') {
                        bat '''
                            terraform validate
                        '''
                    }
                }
            }
        }

        stage('Terraform Import IAM Role') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-creds']
                ]) {
                    dir('terraform') {
                        bat '''
                            terraform state list | findstr /c:"module.ec2.aws_iam_role.ec2_role" >nul

                            if errorlevel 1 (
                                echo Importing existing IAM role...
                                terraform import module.ec2.aws_iam_role.ec2_role cicd-devops-project-ec2-role
                            ) else (
                                echo IAM role already exists in Terraform state. Skipping import.
                            )
                        '''
                    }
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
                            terraform plan
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
                            terraform apply -auto-approve
                        '''
                    }
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
                    ),
                    usernamePassword(
                        credentialsId: 'dockerhub-test',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )
                ]) {
                    bat '''
                        if "%EC2_HOST%"=="YOUR_EC2_PUBLIC_IP" (
                            echo ERROR: EC2_HOST is still set to YOUR_EC2_PUBLIC_IP
                            exit /b 1
                        )

                        echo Deploying to %EC2_HOST%

                        scp -o StrictHostKeyChecking=no -i "%SSH_KEY%" docker-compose.yml %EC2_USER%@%EC2_HOST%:/home/%EC2_USER%/

                        ssh -o StrictHostKeyChecking=no -i "%SSH_KEY%" %EC2_USER%@%EC2_HOST% "echo %DOCKER_PASS% | docker login -u %DOCKER_USER% --password-stdin"

                        ssh -o StrictHostKeyChecking=no -i "%SSH_KEY%" %EC2_USER%@%EC2_HOST% "docker pull %DOCKER_IMAGE%:latest"

                        ssh -o StrictHostKeyChecking=no -i "%SSH_KEY%" %EC2_USER%@%EC2_HOST% "docker stop cicd-demo-app || true"

                        ssh -o StrictHostKeyChecking=no -i "%SSH_KEY%" %EC2_USER%@%EC2_HOST% "docker rm cicd-demo-app || true"

                        ssh -o StrictHostKeyChecking=no -i "%SSH_KEY%" %EC2_USER%@%EC2_HOST% "docker run -d --name cicd-demo-app -p 5000:5000 %DOCKER_IMAGE%:latest"
                    '''
                }
            }
        }

        stage('Health Check') {
            steps {
                bat '''
                    if "%EC2_HOST%"=="YOUR_EC2_PUBLIC_IP" (
                        echo ERROR: EC2_HOST is still set to YOUR_EC2_PUBLIC_IP
                        exit /b 1
                    )

                    echo Checking application at http://%EC2_HOST%:5000/

                    powershell -NoProfile -Command "Invoke-WebRequest -Uri 'http://%EC2_HOST%:5000/' -UseBasicParsing -TimeoutSec 30"
                '''
            }
        }
    }

    post {
        success {
            echo 'CI/CD pipeline completed successfully.'
        }

        failure {
            echo 'CI/CD pipeline failed. Check the stage logs above.'
        }
    }
}
