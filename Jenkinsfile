pipeline {
    agent any

    environment {
        DOCKER_IMAGE = 'princeydv77/cicd-demo-app'
        AWS_REGION = 'ap-south-1'
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

        stage('Python Setup') {
            steps {
                echo '=========================================='
                echo ' STEP 2: PYTHON SETUP'
                echo '=========================================='

                dir('app') {
                    bat '''
                        if exist venv rmdir /s /q venv
                        python -m venv venv
                        call venv\\Scripts\\activate
                        python -m pip install --upgrade pip
                        pip install -r requirements.txt
                        pip install -r requirements-dev.txt
                        pip install flake8 pytest-cov
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

        stage('SonarQube Analysis') {
            steps {
                echo '=========================================='
                echo ' STEP 5: SONARQUBE ANALYSIS'
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
                          -Dsonar.tests=app/tests ^
                          -Dsonar.exclusions=app/tests/** ^
                          -Dsonar.test.inclusions=app/tests/** ^
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
                    trivy fs --exit-code 0 --severity HIGH,CRITICAL .
                '''
            }
        }

        stage('Docker Build') {
            steps {
                echo '=========================================='
                echo ' STEP 7: DOCKER BUILD'
                echo '=========================================='

                bat '''
                    docker build -t %DOCKER_IMAGE%:%BUILD_NUMBER% .
                    docker tag %DOCKER_IMAGE%:%BUILD_NUMBER% %DOCKER_IMAGE%:latest
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
                        if exist "%WORKSPACE%\\.docker" rmdir /s /q "%WORKSPACE%\\.docker"
                        mkdir "%WORKSPACE%\\.docker"

                        powershell -NoProfile -Command "$auth = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($env:DOCKER_USER + ':' + $env:DOCKER_PASS)); $config = @{ auths = @{ 'https://index.docker.io/v1/' = @{ auth = $auth }; 'https://registry-1.docker.io/v2/' = @{ auth = $auth } } } | ConvertTo-Json -Depth 5; Set-Content -Path '%WORKSPACE%\\.docker\\config.json' -Value $config"

                        set "DOCKER_CONFIG=%WORKSPACE%\\.docker"

                        docker push %DOCKER_IMAGE%:%BUILD_NUMBER%
                        if errorlevel 1 exit /b 1

                        docker push %DOCKER_IMAGE%:latest
                        if errorlevel 1 exit /b 1
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
                            terraform init
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

        stage('Terraform IAM Import') {
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
                            terraform plan -var="instance_type=%EC2_INSTANCE_TYPE%" -out=tfplan
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
                            terraform output -raw ec2_public_ip > ec2_public_ip.txt
                        '''
                    }
                }

                script {
                    def ip = readFile('terraform/ec2_public_ip.txt').trim()

                    if (!ip || ip == 'null' || ip == '0.0.0.0') {
                        error("EC2 public IP could not be retrieved from Terraform.")
                    }

                    env.EC2_HOST = ip

                    echo '=========================================='
                    echo "EC2 Public IP: ${env.EC2_HOST}"
                    echo '=========================================='
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
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    bat '''
                        setlocal EnableDelayedExpansion

                        set "SSH_OK=0"

                        for /L %%i in (1,1,12) do (
                            echo Waiting for SSH... attempt %%i/12

                            ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i "%SSH_KEY%" %SSH_USER%@%EC2_HOST% "echo SSH_READY" > ssh_test.txt 2>&1

                            findstr /c:"SSH_READY" ssh_test.txt >nul
                            if not errorlevel 1 (
                                echo SSH connection successful.
                                set "SSH_OK=1"
                                goto :ssh_success
                            )

                            powershell -NoProfile -Command "Start-Sleep -Seconds 10"
                        )

                        :ssh_success

                        if "!SSH_OK!"=="0" (
                            echo SSH connection failed after 12 attempts.
                            type ssh_test.txt
                            exit /b 1
                        )

                        endlocal
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
                        usernameVariable: 'SSH_USER'
                    ),
                    usernamePassword(
                        credentialsId: 'dockerhub-test',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )
                ]) {
                    bat '''
                        ssh -o StrictHostKeyChecking=no -i "%SSH_KEY%" %SSH_USER%@%EC2_HOST% "echo '%DOCKER_PASS%' | docker login -u '%DOCKER_USER%' --password-stdin && docker pull %DOCKER_IMAGE%:latest && docker rm -f cicd-demo-app 2>/dev/null || true && docker run -d --restart unless-stopped --name cicd-demo-app -p 5000:5000 %DOCKER_IMAGE%:latest"
                    '''
                }
            }
        }

        stage('Health Check') {
            steps {
                echo '=========================================='
                echo ' STEP 16: HEALTH CHECK'
                echo '=========================================='

                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'cicd-key',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    bat '''
                        powershell -NoProfile -Command "$url = 'http://%EC2_HOST%:5000/health'; for ($i = 1; $i -le 12; $i++) { try { $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10; if ($r.StatusCode -eq 200) { Write-Host 'Health check successful'; exit 0 } } catch { Write-Host ('Health check attempt ' + $i + ' failed') }; Start-Sleep -Seconds 10 }; Write-Host 'Health check failed'; exit 1"
                    '''
                }
            }
        }
    }

    post {
        always {
            bat '''
                if exist "%WORKSPACE%\\.docker\\config.json" (
                    del /f /q "%WORKSPACE%\\.docker\\config.json"
                )

                if exist "%WORKSPACE%\\.docker" (
                    rmdir /s /q "%WORKSPACE%\\.docker"
                )
            '''
        }

        success {
            echo '=========================================='
            echo ' CI/CD PIPELINE SUCCESSFUL'
            echo '=========================================='
            echo "Application URL: http://${env.EC2_HOST}:5000"
            echo '=========================================='
        }

        failure {
            echo '=========================================='
            echo ' CI/CD PIPELINE FAILED'
            echo '=========================================='
            echo 'Check the failed stage above.'
            echo '=========================================='
        }
    }
}
