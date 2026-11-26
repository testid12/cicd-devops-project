pipeline {
    agent any

    options {
        timestamps()
        timeout(time: 45, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    environment {
        DOCKER_IMAGE = 'princeydv77/cicd-demo-app'
        DOCKER_CREDS = credentials('dockerhub-test')
        AWS_CREDS = credentials('aws-creds')
        SONAR_TOKEN = credentials('sonarqube-token')

        AWS_REGION = 'ap-south-1'
        EC2_INSTANCE_TYPE = 't3.micro'

        EC2_HOST = ''
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
                        pip install -r requirements-dev.txt
                        pip install pytest-cov
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
                echo ' STEP 5: SONARQUBE'
                echo '=========================================='

                withEnv([
                    "SONAR_TOKEN_VALUE=${SONAR_TOKEN}"
                ]) {
                    bat '''
                        sonar-scanner ^
                          -Dsonar.projectKey=cicd-devops-project ^
                          -Dsonar.projectName=cicd-devops-project ^
                          -Dsonar.sources=app ^
                          -Dsonar.tests=app/tests ^
                          -Dsonar.host.url=http://localhost:9000 ^
                          -Dsonar.token=%SONAR_TOKEN_VALUE%
                    '''
                }
            }
        }

        stage('Trivy Security Scan') {
            steps {
                echo '=========================================='
                echo ' STEP 6: TRIVY SECURITY SCAN'
                echo '=========================================='

                bat '''
                    trivy fs --scanners vuln,secret --severity HIGH,CRITICAL --exit-code 0 .
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

                withEnv([
                    "DOCKER_USER_VALUE=${DOCKER_CREDS_USR}",
                    "DOCKER_PASS_VALUE=${DOCKER_CREDS_PSW}"
                ]) {
                    bat '''
                        if exist "%WORKSPACE%\\.docker-jenkins" rmdir /s /q "%WORKSPACE%\\.docker-jenkins"
                        mkdir "%WORKSPACE%\\.docker-jenkins"

                        powershell -NoProfile -Command "$auth = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($env:DOCKER_USER_VALUE + ':' + $env:DOCKER_PASS_VALUE)); $json = '{\"auths\":{\"https://index.docker.io/v1/\":{\"auth\":\"' + $auth + '\"}}}'; Set-Content -Path '%WORKSPACE%\\.docker-jenkins\\config.json' -Value $json -Encoding ASCII"

                        set DOCKER_CONFIG=%WORKSPACE%\\.docker-jenkins

                        docker push %DOCKER_IMAGE%:%BUILD_NUMBER%
                        docker push %DOCKER_IMAGE%:latest

                        rmdir /s /q "%WORKSPACE%\\.docker-jenkins"
                    '''
                }
            }
        }

        stage('Terraform Init') {
            steps {
                echo '=========================================='
                echo ' STEP 9: TERRAFORM INIT'
                echo '=========================================='

                dir('terraform') {
                    bat '''
                        terraform init -input=false
                    '''
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                echo '=========================================='
                echo ' STEP 10: TERRAFORM VALIDATE'
                echo '=========================================='

                dir('terraform') {
                    bat '''
                        terraform validate
                    '''
                }
            }
        }

        stage('Terraform Import Existing IAM Resources') {
            steps {
                echo '=========================================='
                echo ' STEP 11: IMPORT EXISTING IAM RESOURCES'
                echo '=========================================='

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

        stage('Terraform Plan') {
            steps {
                echo '=========================================='
                echo ' STEP 12: TERRAFORM PLAN'
                echo '=========================================='

                dir('terraform') {
                    bat '''
                        terraform plan ^
                          -input=false ^
                          -var="instance_type=%EC2_INSTANCE_TYPE%" ^
                          -out=tfplan
                    '''
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                echo '=========================================='
                echo ' STEP 13: TERRAFORM APPLY'
                echo '=========================================='

                dir('terraform') {
                    bat '''
                        terraform apply -input=false -auto-approve tfplan
                    '''
                }
            }
        }

        stage('Get EC2 Public IP') {
            steps {
                echo '=========================================='
                echo ' STEP 14: GET EC2 PUBLIC IP'
                echo '=========================================='

                dir('terraform') {
                    bat '''
                        terraform output -raw ec2_public_ip > ec2_public_ip.txt
                    '''
                }

                script {
                    def ip = readFile('terraform/ec2_public_ip.txt').trim()

                    if (!ip || ip == 'null' || ip == '0.0.0.0') {
                        error("Terraform did not return a valid EC2 public IP. Value: '${ip}'")
                    }

                    env.EC2_HOST = ip

                    echo "EC2 Public IP: ${env.EC2_HOST}"
                }
            }
        }

        stage('Wait for SSH') {
            steps {
                echo '=========================================='
                echo ' STEP 15: WAIT FOR SSH'
                echo '=========================================='

                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'cicd-key',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    bat '''
                        @echo off
                        setlocal EnableDelayedExpansion

                        set "HOST=%EC2_HOST%"
                        set "USER=%SSH_USER%"

                        echo Waiting for SSH on %USER%@%HOST% ...

                        set "SSH_OK=0"

                        for /L %%i in (1,1,12) do (
                            echo SSH attempt %%i of 12...

                            ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes -i "%SSH_KEY%" %USER%@%HOST% "echo SSH_READY" > ssh_check.txt 2>&1

                            if !ERRORLEVEL! EQU 0 (
                                findstr /c:"SSH_READY" ssh_check.txt >nul
                                if !ERRORLEVEL! EQU 0 (
                                    set "SSH_OK=1"
                                    goto :ssh_success
                                )
                            )

                            if %%i LSS 12 (
                                echo SSH not ready. Waiting 10 seconds...
                                powershell -NoProfile -Command "Start-Sleep -Seconds 10"
                            )
                        )

                        :ssh_success

                        if "%SSH_OK%"=="0" (
                            echo ERROR: SSH connection to %USER%@%HOST% failed.
                            type ssh_check.txt
                            exit /b 1
                        )

                        echo SSH connection successful.
                    '''
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
                echo '=========================================='
                echo ' STEP 16: DEPLOY TO EC2'
                echo '=========================================='

                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'cicd-key',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    withEnv([
                        "DOCKER_USER_VALUE=${DOCKER_CREDS_USR}",
                        "DOCKER_PASS_VALUE=${DOCKER_CREDS_PSW}"
                    ]) {
                        bat '''
                            @echo off

                            echo Deploying Docker container to %EC2_HOST% ...

                            powershell -NoProfile -Command "$env:DOCKER_PASS_VALUE | ssh -o StrictHostKeyChecking=no -i '%SSH_KEY%' %SSH_USER%@%EC2_HOST% 'docker login -u %DOCKER_USER_VALUE% --password-stdin'"

                            if errorlevel 1 (
                                echo ERROR: Docker login on EC2 failed.
                                exit /b 1
                            )

                            ssh -o StrictHostKeyChecking=no -i "%SSH_KEY%" %SSH_USER%@%EC2_HOST% "docker pull %DOCKER_IMAGE%:latest"

                            if errorlevel 1 (
                                echo ERROR: Docker pull on EC2 failed.
                                exit /b 1
                            )

                            ssh -o StrictHostKeyChecking=no -i "%SSH_KEY%" %SSH_USER%@%EC2_HOST% "docker rm -f cicd-demo-app > /dev/null 2>&1 || true"

                            ssh -o StrictHostKeyChecking=no -i "%SSH_KEY%" %SSH_USER%@%EC2_HOST% "docker run -d --restart unless-stopped --name cicd-demo-app -p 5000:5000 %DOCKER_IMAGE%:latest"

                            if errorlevel 1 (
                                echo ERROR: Docker container start failed.
                                exit /b 1
                            )

                            echo Deployment completed successfully.
                        '''
                    }
                }
            }
        }

        stage('Application Health Check') {
            steps {
                echo '=========================================='
                echo ' STEP 17: APPLICATION HEALTH CHECK'
                echo '=========================================='

                bat '''
                    @echo off

                    echo Waiting for application to become healthy...

                    powershell -NoProfile -Command "$url = 'http://%EC2_HOST%:5000'; $ok = $false; for ($i = 1; $i -le 12; $i++) { try { $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10; if ($r.StatusCode -eq 200) { Write-Host 'Application is healthy.'; $ok = $true; break } } catch { Write-Host ('Health check attempt ' + $i + ' failed.') }; if ($i -lt 12) { Start-Sleep -Seconds 10 } }; if (-not $ok) { Write-Error 'Application health check failed.'; exit 1 }"
                '''
            }
        }
    }

    post {
        success {
            echo '=========================================='
            echo ' CI/CD PIPELINE SUCCESS'
            echo '=========================================='
            echo "Application URL: http://${env.EC2_HOST}:5000"
            echo "Docker Image: ${env.DOCKER_IMAGE}:latest"
        }

        failure {
            echo '=========================================='
            echo ' CI/CD PIPELINE FAILED'
            echo '=========================================='
            echo "EC2_HOST at failure: ${env.EC2_HOST}"
        }

        always {
            echo 'Pipeline execution finished.'
        }
    }
}
