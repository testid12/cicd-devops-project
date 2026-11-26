pipeline {
    agent any

    environment {
        DOCKER_IMAGE = 'princeydv77/cicd-demo-app'
        AWS_REGION   = 'ap-south-1'
        EC2_USER     = 'ubuntu'
        EC2_HOST     = ''
        EC2_INSTANCE_TYPE = 't3.micro'
    }

    stages {

        stage('Checkout') {
            steps {
                echo '=========================================='
                echo ' STEP 1: CHECKOUT'
                echo '=========================================='

                checkout scm
            }
        }

        stage('Setup Python') {
            steps {
                echo '=========================================='
                echo ' STEP 2: SETUP PYTHON'
                echo '=========================================='

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
                echo '=========================================='
                echo ' STEP 3: TESTS'
                echo '=========================================='

                dir('app') {
                    bat '''
                        call venv\\Scripts\\activate

                        pytest -v --cov=. --cov-report=term-missing
                    '''
                }
            }
        }

        stage('Flake8') {
            steps {
                echo '=========================================='
                echo ' STEP 4: FLAKE8'
                echo '=========================================='

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
                echo '=========================================='
                echo ' STEP 5: SONARQUBE'
                echo '=========================================='

                withCredentials([
                    string(
                        credentialsId: 'sonarqube-token',
                        variable: 'SONAR_TOKEN'
                    )
                ]) {
                    bat '''
                        sonar-scanner ^
                          -Dsonar.projectKey=cicd-devops-project ^
                          -Dsonar.projectName=cicd-devops-project ^
                          -Dsonar.sources=app ^
                          -Dsonar.python.version=3.12 ^
                          -Dsonar.host.url=http://localhost:9000 ^
                          -Dsonar.token=%SONAR_TOKEN%
                    '''
                }
            }
        }

        stage('Security Scan') {
            steps {
                echo '=========================================='
                echo ' STEP 6: SECURITY SCAN'
                echo '=========================================='

                bat '''
                    trivy fs . --exit-code 0 --severity HIGH,CRITICAL
                '''
            }
        }

        stage('Docker Build') {
            steps {
                echo '=========================================='
                echo ' STEP 7: DOCKER BUILD'
                echo '=========================================='

                bat '''
                    docker --version

                    docker build ^
                      -t %DOCKER_IMAGE%:%BUILD_NUMBER% ^
                      -t %DOCKER_IMAGE%:latest ^
                      .
                '''
            }
        }

        stage('Docker Push') {
            steps {
                echo '=========================================='
                echo ' STEP 8: DOCKER PUSH'
                echo '=========================================='

                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-test',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )
                ]) {
                    bat '''
                        set DOCKER_CONFIG=%WORKSPACE%\\.docker

                        if exist "%WORKSPACE%\\.docker" (
                            rmdir /s /q "%WORKSPACE%\\.docker"
                        )

                        mkdir "%WORKSPACE%\\.docker"

                        powershell -NoProfile -Command "$auth=[Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($env:DOCKER_USER + ':' + $env:DOCKER_PASS)); $json='{\\\"auths\\\":{\\\"https://index.docker.io/v1/\\\":{\\\"auth\\\":\\\"' + $auth + '\\\"}}}'; Set-Content -Path ($env:DOCKER_CONFIG + '\\config.json') -Value $json -Encoding ASCII"

                        docker push %DOCKER_IMAGE%:%BUILD_NUMBER%

                        docker push %DOCKER_IMAGE%:latest

                        del /f /q "%WORKSPACE%\\.docker\\config.json"
                    '''
                }
            }
        }

        stage('Terraform Init') {
            steps {
                echo '=========================================='
                echo ' STEP 9: TERRAFORM INIT'
                echo '=========================================='

                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-creds']
                ]) {
                    dir('terraform') {
                        bat '''
                            terraform init -input=false
                        '''
                    }
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                echo '=========================================='
                echo ' STEP 10: TERRAFORM VALIDATE'
                echo '=========================================='

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

        stage('Terraform Import IAM Resources') {
            steps {
                echo '=========================================='
                echo ' STEP 11: TERRAFORM IAM IMPORT'
                echo '=========================================='

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

                            terraform state list | findstr /c:"module.ec2.aws_iam_instance_profile.ec2_profile" >nul

                            if errorlevel 1 (
                                echo Importing existing IAM instance profile...
                                terraform import module.ec2.aws_iam_instance_profile.ec2_profile cicd-devops-project-ec2-profile
                            ) else (
                                echo IAM instance profile already exists in Terraform state. Skipping import.
                            )
                        '''
                    }
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                echo '=========================================='
                echo ' STEP 12: TERRAFORM PLAN'
                echo '=========================================='

                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-creds']
                ]) {
                    dir('terraform') {
                        bat '''
                            echo.
                            echo ==========================================
                            echo FORCING EC2 INSTANCE TYPE: t3.micro
                            echo ==========================================
                            echo.

                            terraform plan ^
                              -var="instance_type=%EC2_INSTANCE_TYPE%" ^
                              -out=tfplan
                        '''
                    }
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                echo '=========================================='
                echo ' STEP 13: TERRAFORM APPLY'
                echo '=========================================='

                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: 'aws-creds']
                ]) {
                    dir('terraform') {
                        bat '''
                            terraform apply -auto-approve tfplan

                            terraform output -raw ec2_public_ip > ec2_ip.txt
                        '''
                    }
                }

                script {
                    def ec2Host = readFile(
                        file: 'terraform/ec2_ip.txt'
                    ).trim()

                    env.EC2_HOST = ec2Host

                    echo "EC2 Public IP: ${env.EC2_HOST}"
                }
            }
        }

        stage('Wait for SSH') {
            steps {
                echo '=========================================='
                echo ' STEP 14: WAIT FOR EC2 SSH'
                echo '=========================================='

                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'cicd-key',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USERNAME'
                    )
                ]) {
                    bat '''
                        echo Waiting for EC2 SSH to become available...

                        set "SSH_HOST=%EC2_HOST%"

                        for /L %%i in (1,1,30) do (
                            echo SSH attempt %%i/30

                            ssh -o StrictHostKeyChecking=no ^
                                -o ConnectTimeout=5 ^
                                -o BatchMode=yes ^
                                -i "%SSH_KEY%" ^
                                %SSH_USERNAME%@%SSH_HOST% "echo SSH_READY" >nul 2>&1

                            if not errorlevel 1 (
                                echo SSH is ready.
                                exit /b 0
                            )

                            timeout /t 10 /nobreak >nul
                        )

                        echo SSH did not become ready within the expected time.
                        exit /b 1
                    '''
                }
            }
        }

        stage('Deploy') {
            steps {
                echo '=========================================='
                echo ' STEP 15: DEPLOY'
                echo '=========================================='

                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'cicd-key',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USERNAME'
                    ),

                    usernamePassword(
                        credentialsId: 'dockerhub-test',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )
                ]) {
                    bat '''
                        echo Deploying to EC2 host: %EC2_HOST%

                        echo.
                        echo Copying deployment script to EC2...
                        echo.

                        scp -o StrictHostKeyChecking=no ^
                            -i "%SSH_KEY%" ^
                            scripts\\deploy.sh ^
                            %SSH_USERNAME%@%EC2_HOST%:/tmp/deploy.sh

                        echo.
                        echo Running deployment on EC2...
                        echo.

                        ssh -o StrictHostKeyChecking=no ^
                            -i "%SSH_KEY%" ^
                            %SSH_USERNAME%@%EC2_HOST% ^
                            "chmod +x /tmp/deploy.sh && sudo /tmp/deploy.sh %DOCKER_IMAGE% %DOCKER_PASS%"
                    '''
                }
            }
        }

        stage('Health Check') {
            steps {
                echo '=========================================='
                echo ' STEP 16: HEALTH CHECK'
                echo '=========================================='

                bat '''
                    echo Checking application at:
                    echo http://%EC2_HOST%:5000/

                    powershell -NoProfile -Command "$url='http://%EC2_HOST%:5000/'; $response=Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20; Write-Host ('HTTP Status: ' + $response.StatusCode); if ($response.StatusCode -ne 200) { exit 1 }"

                    echo.
                    echo ==========================================
                    echo APPLICATION HEALTH CHECK PASSED
                    echo ==========================================
                '''
            }
        }
    }

    post {
        success {
            echo ''
            echo '=========================================='
            echo ' CI/CD PIPELINE SUCCESSFUL'
            echo '=========================================='
            echo "Docker Image: %DOCKER_IMAGE%:latest"
            echo "EC2 Host: %EC2_HOST%"
            echo "Application: http://%EC2_HOST%:5000/"
            echo '=========================================='
        }

        failure {
            echo ''
            echo '=========================================='
            echo ' CI/CD PIPELINE FAILED'
            echo '=========================================='
            echo 'Check the failed stage above.'
            echo '=========================================='
        }

        always {
            bat '''
                if exist "%WORKSPACE%\\.docker\\config.json" (
                    del /f /q "%WORKSPACE%\\.docker\\config.json"
                )
            '''
        }
    }
}
