pipeline {
    agent any

    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
    }

    environment {
        DOCKER_IMAGE       = 'princeydv77/cicd-demo-app'
        DOCKER_TAG         = "${BUILD_NUMBER}"
        DOCKER_LATEST      = 'latest'

        AWS_REGION         = 'ap-south-1'
        EC2_INSTANCE_TYPE  = 't3.micro'
        EC2_HOST           = ''

        DOCKER_CONFIG      = "${WORKSPACE}\\.docker"
        DOCKER_CREDS       = credentials('dockerhub-test')
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

                        powershell -NoProfile -Command ^
                          "$auth = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('%DOCKER_USER%:%DOCKER_PASS%')); ^
                           $json = @{auths=@{'https://index.docker.io/v1/'=@{auth=$auth}}} | ConvertTo-Json -Depth 5; ^
                           Set-Content -Path '%DOCKER_CONFIG%\\config.json' -Value $json"

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

                            echo.
                            echo ==========================================
                            echo SAVING EC2 PUBLIC IP
                            echo ==========================================

                            terraform output -raw ec2_public_ip > ec2_public_ip.txt

                            echo.
                            echo EC2 IP saved to:
                            type ec2_public_ip.txt
                            echo.
                        '''
                    }
                }

                script {
                    dir('terraform') {
                        def ip = bat(
                            script: 'type ec2_public_ip.txt',
                            returnStdout: true
                        ).trim()

                        echo '=========================================='
                        echo "EC2 Public IP: ${ip}"
                        echo '=========================================='

                        if (!ip || ip == 'null' || ip == '0.0.0.0') {
                            error("EC2 public IP could not be obtained from Terraform.")
                        }

                        env.EC2_HOST = ip
                    }
                }
            }
        }

        stage('Wait for SSH') {
            steps {
                echo '=========================================='
                echo ' STEP 14: WAIT FOR EC2 SSH'
                echo '=========================================='

                script {
                    if (!env.EC2_HOST?.trim()) {
                        error('EC2_HOST is empty. Cannot connect to EC2.')
                    }

                    echo "Waiting for SSH on ${env.EC2_HOST}..."

                    def connected = false

                    for (int i = 1; i <= 12; i++) {
                        try {
                            sshagent(credentials: ['cicd-key']) {
                                bat """
                                    ssh -o StrictHostKeyChecking=no ^
                                        -o ConnectTimeout=5 ^
                                        ubuntu@${env.EC2_HOST} ^
                                        "echo SSH_OK"
                                """
                            }

                            connected = true
                            echo 'SSH connection successful.'
                            break

                        } catch (Exception e) {
                            echo "SSH attempt ${i}/12 failed. Waiting 10 seconds..."
                            sleep time: 10, unit: 'SECONDS'
                        }
                    }

                    if (!connected) {
                        error("Unable to establish SSH connection to ${env.EC2_HOST}.")
                    }
                }
            }
        }

        stage('Deploy') {
            steps {
                echo '=========================================='
                echo ' STEP 15: DEPLOY TO EC2'
                echo '=========================================='

                script {
                    if (!env.EC2_HOST?.trim()) {
                        error('EC2_HOST is empty. Cannot deploy.')
                    }

                    withCredentials([
                        usernamePassword(
                            credentialsId: 'dockerhub-test',
                            usernameVariable: 'DOCKER_USER',
                            passwordVariable: 'DOCKER_PASS'
                        )
                    ]) {
                        sshagent(credentials: ['cicd-key']) {

                            bat """
                                ssh -o StrictHostKeyChecking=no ubuntu@${env.EC2_HOST} ^
                                  "echo '%DOCKER_PASS%' | docker login -u '%DOCKER_USER%' --password-stdin && ^
                                   docker pull %DOCKER_IMAGE%:%DOCKER_LATEST% && ^
                                   docker rm -f cicd-demo-app 2>nul || true && ^
                                   docker run -d --name cicd-demo-app -p 5000:5000 %DOCKER_IMAGE%:%DOCKER_LATEST%"
                            """
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
                    if (!env.EC2_HOST?.trim()) {
                        error('EC2_HOST is empty. Cannot run health check.')
                    }

                    echo "Checking application at http://${env.EC2_HOST}:5000/"

                    def healthy = false

                    for (int i = 1; i <= 12; i++) {
                        try {
                            powershell """
                                \$response = Invoke-WebRequest `
                                    -Uri "http://${env.EC2_HOST}:5000/" `
                                    -UseBasicParsing `
                                    -TimeoutSec 10

                                Write-Host "HTTP Status: \$($response.StatusCode)"

                                if (\$response.StatusCode -ne 200) {
                                    exit 1
                                }
                            """

                            healthy = true
                            echo 'Application health check PASSED.'
                            break

                        } catch (Exception e) {
                            echo "Health check attempt ${i}/12 failed. Waiting 10 seconds..."
                            sleep time: 10, unit: 'SECONDS'
                        }
                    }

                    if (!healthy) {
                        error("Application health check failed for http://${env.EC2_HOST}:5000/")
                    }
                }
            }
        }
    }

    post {
        always {
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
