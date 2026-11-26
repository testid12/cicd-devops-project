pipeline {

    agent any

    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
    }

    environment {
        DOCKER_IMAGE      = 'princeydv77/cicd-demo-app'
        DOCKER_TAG        = "${BUILD_NUMBER}"
        DOCKER_LATEST     = 'latest'

        AWS_REGION        = 'ap-south-1'
        EC2_INSTANCE_TYPE = 't3.micro'

        EC2_HOST          = ''

        DOCKER_CONFIG     = "${WORKSPACE}\\.docker"
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
                echo ' STEP 2: PYTHON SETUP'
                echo '=========================================='

                dir('app') {
                    bat '''
                        if exist venv rmdir /s /q venv

                        python -m venv venv

                        call venv\\Scripts\\activate

                        python -m pip install --upgrade pip

                        pip install -r requirements.txt

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

                        pytest --cov=. --cov-report=term-missing
                    '''
                }
            }
        }


        stage('Code Quality') {
            steps {
                echo '=========================================='
                echo ' STEP 4: CODE QUALITY'
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
                          -Dsonar.host.url=http://localhost:9000 ^
                          -Dsonar.token=%SONAR_TOKEN%
                    '''
                }
            }
        }


        stage('Security Scan') {
            steps {
                echo '=========================================='
                echo ' STEP 6: TRIVY SECURITY SCAN'
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
                    docker build -t %DOCKER_IMAGE%:%DOCKER_TAG% .
                    docker tag %DOCKER_IMAGE%:%DOCKER_TAG% %DOCKER_IMAGE%:%DOCKER_LATEST%
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
                        if exist "%DOCKER_CONFIG%" rmdir /s /q "%DOCKER_CONFIG%"
                        mkdir "%DOCKER_CONFIG%"

                        powershell -NoProfile -Command "$auth=[Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($env:DOCKER_USER + ':' + $env:DOCKER_PASS)); $json='{\\\"auths\\\":{\\\"https://index.docker.io/v1/\\\":{\\\"auth\\\":\\\"' + $auth + '\\\"}}}'; Set-Content -Path ($env:DOCKER_CONFIG + '\\config.json') -Value $json -Encoding ASCII"

                        docker push %DOCKER_IMAGE%:%DOCKER_TAG%
                        docker push %DOCKER_IMAGE%:%DOCKER_LATEST%
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


        stage('Terraform IAM Import') {
            steps {
                echo '=========================================='
                echo ' STEP 11: TERRAFORM IAM IMPORT'
                echo '=========================================='

                dir('terraform') {

                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                         credentialsId: 'aws-creds']
                    ]) {

                        bat '''
                            terraform state list | findstr /c:"module.ec2.aws_iam_role.ec2_role" >nul

                            if errorlevel 1 (
                                echo IAM role not found in Terraform state. Importing...
                                terraform import module.ec2.aws_iam_role.ec2_role cicd-devops-project-ec2-role
                            ) else (
                                echo IAM role already exists in Terraform state. Skipping import.
                            )

                            terraform state list | findstr /c:"module.ec2.aws_iam_instance_profile.ec2_profile" >nul

                            if errorlevel 1 (
                                echo IAM instance profile not found in Terraform state. Importing...
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

                dir('terraform') {

                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                         credentialsId: 'aws-creds']
                    ]) {

                        bat '''
                            terraform plan ^
                              -input=false ^
                              -var="instance_type=%EC2_INSTANCE_TYPE%" ^
                              -var="docker_image=%DOCKER_IMAGE%:%DOCKER_LATEST%" ^
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

                dir('terraform') {

                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                         credentialsId: 'aws-creds']
                    ]) {

                        bat '''
                            terraform apply -input=false -auto-approve tfplan

                            terraform output -raw ec2_public_ip > ec2_public_ip.txt
                        '''
                    }

                    script {

                        def ip = readFile(
                            file: 'terraform/ec2_public_ip.txt'
                        ).trim()

                        if (!ip || ip == 'null') {
                            error("Terraform created/applied successfully, but EC2 public IP could not be captured.")
                        }

                        env.EC2_HOST = ip

                        echo "=========================================="
                        echo " EC2 PUBLIC IP: ${env.EC2_HOST}"
                        echo " APPLICATION URL: http://${env.EC2_HOST}:5000"
                        echo "=========================================="
                    }
                }
            }
        }


        stage('Wait for SSH') {
            steps {
                echo '=========================================='
                echo ' STEP 14: WAIT FOR SSH'
                echo '=========================================='

                script {

                    if (!env.EC2_HOST || env.EC2_HOST == 'null') {
                        error("EC2_HOST is empty. Cannot connect to EC2.")
                    }

                    sshagent(credentials: ['cicd-key']) {

                        bat '''
                            set SSH_OK=0

                            for /L %%i in (1,1,12) do (
                                echo Attempt %%i/12 to connect to %EC2_HOST%

                                ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@%EC2_HOST% "echo SSH_OK"

                                if not errorlevel 1 (
                                    set SSH_OK=1
                                    goto :ssh_success
                                )

                                timeout /t 10 /nobreak >nul
                            )

                            :ssh_success

                            if "%SSH_OK%"=="1" (
                                echo SSH connection successful.
                                exit /b 0
                            )

                            echo SSH connection failed after 12 attempts.
                            exit /b 1
                        '''
                    }
                }
            }
        }


        stage('Deploy') {
            steps {
                echo '=========================================='
                echo ' STEP 15: DEPLOY APPLICATION'
                echo '=========================================='

                script {

                    if (!env.EC2_HOST || env.EC2_HOST == 'null') {
                        error("EC2_HOST is empty. Cannot deploy.")
                    }

                    sshagent(credentials: ['cicd-key']) {

                        withCredentials([
                            usernamePassword(
                                credentialsId: 'dockerhub-test',
                                usernameVariable: 'DOCKER_USER',
                                passwordVariable: 'DOCKER_PASS'
                            )
                        ]) {

                            bat '''
                                ssh -o StrictHostKeyChecking=no ubuntu@%EC2_HOST% "echo '%DOCKER_PASS%' | docker login -u '%DOCKER_USER%' --password-stdin && docker pull %DOCKER_IMAGE%:%DOCKER_LATEST% && docker rm -f cicd-demo-app 2>/dev/null || true && docker run -d --name cicd-demo-app --restart unless-stopped -p 5000:5000 %DOCKER_IMAGE%:%DOCKER_LATEST%"
                            '''
                        }
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

                    if (!env.EC2_HOST || env.EC2_HOST == 'null') {
                        error("EC2_HOST is empty. Cannot perform health check.")
                    }

                    def healthy = false

                    for (int i = 1; i <= 12; i++) {

                        echo "Health check attempt ${i}/12..."

                        try {

                            powershell """
                                try {
                                    \$response = Invoke-WebRequest -Uri "http://${env.EC2_HOST}:5000/" -UseBasicParsing -TimeoutSec 10

                                    if (\$response.StatusCode -eq 200) {
                                        Write-Host "APPLICATION HEALTH CHECK PASSED"
                                        exit 0
                                    }

                                    exit 1
                                }
                                catch {
                                    Write-Host "Application not ready yet."
                                    exit 1
                                }
                            """

                            healthy = true
                            break

                        } catch (Exception e) {

                            if (i < 12) {
                                Start-Sleep -Seconds 10
                            }
                        }
                    }

                    if (!healthy) {
                        error("Application health check failed after 12 attempts.")
                    }

                    echo '=========================================='
                    echo ' APPLICATION IS LIVE'
                    echo " URL: http://${env.EC2_HOST}:5000/"
                    echo '=========================================='
                }
            }
        }
    }


    post {

        always {
            echo '=========================================='
            echo ' CLEANUP'
            echo '=========================================='

            bat '''
                if exist "%DOCKER_CONFIG%\\config.json" (
                    del /f /q "%DOCKER_CONFIG%\\config.json"
                )

                if exist "%DOCKER_CONFIG%" (
                    rmdir /s /q "%DOCKER_CONFIG%"
                )
            '''
        }

        success {
            echo '=========================================='
            echo ' CI/CD PIPELINE SUCCESS'
            echo '=========================================='

            script {
                if (env.EC2_HOST) {
                    echo "Application URL: http://${env.EC2_HOST}:5000/"
                }
            }

            echo 'Docker image pushed successfully.'
            echo 'Terraform deployment completed successfully.'
            echo 'Application deployment completed successfully.'
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
