pipeline {
    agent any

    environment {
        DOCKER_IMAGE = 'princeydv77/cicd-demo-app'
        EC2_INSTANCE_TYPE = 't3.micro'
        EC2_HOST = ''
    }

    options {
        timestamps()
        timeout(time: 45, unit: 'MINUTES')
    }

    stages {

        stage('Checkout') {
            steps {
                echo '=========================================='
                echo ' STEP 1: CHECKOUT'
                echo '=========================================='

                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/main']],
                    userRemoteConfigs: [[
                        url: 'https://github.com/testid12/cicd-devops-project.git'
                    ]]
                ])
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
                    trivy fs --scanners vuln,secret .
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

                dir('terraform') {
                    bat '''
                        terraform validate
                    '''
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
                                terraform import module.ec2.aws_iam_role.ec2_role cicd-devops-project-ec2-role
                            ) else (
                                echo IAM role already exists in Terraform state. Skipping import.
                            )

                            terraform state list | findstr /c:"module.ec2.aws_iam_instance_profile.ec2_profile" >nul
                            if errorlevel 1 (
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

                            terraform output -raw ec2_public_ip > ec2_public_ip.txt

                            echo.
                            echo ===== EC2 IP FROM TERRAFORM =====
                            type ec2_public_ip.txt
                            echo ================================
                        '''
                    }
                }

                script {
                    def ipFile = 'terraform/ec2_public_ip.txt'

                    if (!fileExists(ipFile)) {
                        error("ERROR: Terraform IP file was not created: ${ipFile}")
                    }

                    def ip = readFile(ipFile).trim()

                    echo '=========================================='
                    echo "EC2 Public IP read from file: ${ip}"
                    echo '=========================================='

                    if (!ip || ip == 'null') {
                        error("ERROR: Terraform returned an empty EC2 Public IP: '${ip}'")
                    }

                    env.EC2_HOST = ip
                }
            }
        }

        stage('Wait for SSH') {
            steps {
                echo '=========================================='
                echo ' STEP 14: WAIT FOR SSH'
                echo '=========================================='

                script {
                    def ec2Host = readFile('terraform/ec2_public_ip.txt').trim()

                    echo "SSH target EC2 IP: ${ec2Host}"

                    if (!ec2Host || ec2Host == 'null') {
                        error("ERROR: EC2 Public IP is empty: '${ec2Host}'")
                    }

                    withCredentials([
                        sshUserPrivateKey(
                            credentialsId: 'cicd-key',
                            keyFileVariable: 'SSH_KEY',
                            usernameVariable: 'SSH_USER'
                        )
                    ]) {
                        bat """
                            echo SSH_USER=%SSH_USER%
                            echo EC2_HOST=${ec2Host}
                            echo SSH_KEY=%SSH_KEY%

                            icacls "%SSH_KEY%" /inheritance:r
                            icacls "%SSH_KEY%" /grant:r "SYSTEM:R"

                            if errorlevel 1 (
                                echo ERROR: Failed to set SSH key permissions.
                                exit /b 1
                            )

                            ssh-keygen -y -f "%SSH_KEY%" >nul

                            if errorlevel 1 (
                                echo ERROR: Jenkins SSH private key cannot be parsed by OpenSSH.
                                exit /b 1
                            )

                            echo SSH key format is valid.

                           for /L %%i in (1,1,12) do (
    echo.
    echo ===== SSH ATTEMPT %%i/12 =====

    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes -i "%SSH_KEY%" %SSH_USER%@${ec2Host} "echo SSH connection successful"

    if not errorlevel 1 (
        echo.
        echo ==========================================
        echo SSH CONNECTION SUCCESSFUL
        echo ==========================================
        exit /b 0
    )

    echo SSH not ready yet. Waiting 10 seconds...
    timeout /t 10 /nobreak >nul
)

echo.
echo ERROR: Could not connect to EC2 through SSH after 12 attempts.
exit /b 1
                        """
                    }
                }
            }
        }

        stage('Deploy') {
            steps {
                echo '=========================================='
                echo ' STEP 15: DEPLOY'
                echo '=========================================='

                script {
                    def ec2Host = readFile('terraform/ec2_public_ip.txt').trim()

                    if (!ec2Host || ec2Host == 'null') {
                        error("ERROR: EC2 Public IP is empty: '${ec2Host}'")
                    }

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
                        bat """
                            icacls "%SSH_KEY%" /inheritance:r
                            icacls "%SSH_KEY%" /grant:r "SYSTEM:R"

                            if errorlevel 1 (
                                echo ERROR: Failed to set SSH key permissions.
                                exit /b 1
                            )

                            echo.
                            echo ==========================================
                            echo DEPLOYING TO EC2: ${ec2Host}
                            echo ==========================================

                            ssh -o StrictHostKeyChecking=no -o ConnectTimeout=15 -o BatchMode=yes -i "%SSH_KEY%" %SSH_USER%@${ec2Host} "echo '%DOCKER_PASS%' | docker login -u '%DOCKER_USER%' --password-stdin && docker pull %DOCKER_IMAGE%:latest && docker rm -f cicd-demo-app 2>/dev/null || true && docker run -d --name cicd-demo-app -p 5000:5000 --restart unless-stopped %DOCKER_IMAGE%:latest"

                            if errorlevel 1 (
                                echo ERROR: Deployment failed.
                                exit /b 1
                            )

                            echo.
                            echo ==========================================
                            echo DEPLOYMENT SUCCESSFUL
                            echo ==========================================
                        """
                    }
                }
            }
        }

      stage('Health Check') {
    steps {
        echo '=========================================='
        echo ' STEP 16: HEALTH CHECK'
        echo '=========================================='

        script {
            def ec2Host = readFile('terraform/ec2_public_ip.txt').trim()

            if (!ec2Host || ec2Host == 'null') {
                error("ERROR: EC2 Public IP is empty: '${ec2Host}'")
            }

            echo "Checking application health at http://${ec2Host}:5000/health"

            bat """
                powershell -NoProfile -Command "try { \$r = Invoke-WebRequest -Uri 'http://${ec2Host}:5000/health' -UseBasicParsing -TimeoutSec 20; Write-Host 'HTTP Status:' \$r.StatusCode; Write-Host 'Response:' \$r.Content; if (\$r.StatusCode -eq 200) { exit 0 } else { exit 1 } } catch { Write-Host 'Health check failed:' \$_.Exception.Message; exit 1 }"
            """
        }
    }
}
