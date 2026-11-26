pipeline {
    agent any

    options {
        timestamps()
        timeout(time: 45, unit: 'MINUTES')
    }

    environment {
        DOCKER_IMAGE = 'princeydv77/cicd-demo-app'
        DOCKER_TAG = "${BUILD_NUMBER}"
        DOCKER_LATEST = 'latest'

        AWS_REGION = 'ap-south-1'
        EC2_INSTANCE_TYPE = 't3.micro'
        EC2_HOST = ''

        DOCKER_CONFIG = "${WORKSPACE}\\.docker"

        DOCKER_CREDS = credentials('dockerhub-test')
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
                echo ' STEP 3: RUN TESTS'
                echo '=========================================='

                dir('app') {
                    bat '''
                        call venv\\Scripts\\activate

                        pytest -v ^
                          --junitxml=../test-results.xml ^
                          --cov=. ^
                          --cov-report=term-missing ^
                          --cov-report=xml
                    '''
                }
            }

            post {
                always {
                    junit 'test-results.xml'
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

                        echo.
                        echo ==========================================
                        echo Running Flake8
                        echo ==========================================

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

                script {
                    def scannerHome = tool 'SonarScanner'

                    withSonarQubeEnv('SonarQube') {
                        withCredentials([
                            string(
                                credentialsId: 'sonarqube-token',
                                variable: 'SONAR_TOKEN'
                            )
                        ]) {
                            bat """
                                "${scannerHome}\\bin\\sonar-scanner.bat" ^
                                  -Dsonar.projectKey=cicd-devops-project ^
                                  -Dsonar.projectName=cicd-devops-project ^
                                  -Dsonar.sources=app ^
                                  -Dsonar.python.version=3.11 ^
                                  -Dsonar.host.url=%SONAR_HOST_URL% ^
                                  -Dsonar.token=%SONAR_TOKEN%
                            """
                        }
                    }
                }
            }
        }

        stage('Security Scan') {
            steps {
                echo '=========================================='
                echo ' STEP 6: TRIVY SECURITY SCAN'
                echo '=========================================='

                bat '''
                    trivy fs --severity HIGH,CRITICAL --exit-code 0 .
                '''
            }
        }

        stage('Docker Build') {
            steps {
                echo '=========================================='
                echo ' STEP 7: DOCKER BUILD'
                echo '=========================================='

                bat """
                    docker build -t %DOCKER_IMAGE%:%DOCKER_TAG% .
                    docker tag %DOCKER_IMAGE%:%DOCKER_TAG% %DOCKER_IMAGE%:%DOCKER_LATEST%
                """
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
                          "$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($env:DOCKER_USER + ':' + $env:DOCKER_PASS));" ^
                          "$json = '{\\\"auths\\\":{\\\"https://index.docker.io/v1/\\\":{\\\"auth\\\":\\\"' + $auth + '\\\"}}}';" ^
                          "Set-Content -Path '%DOCKER_CONFIG%\\config.json' -Value $json -Encoding ASCII"

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

                            terraform plan ^
                              -var="instance_type=t3.micro" ^
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
                        '''
                    }
                }

                script {
                    dir('terraform') {
                        def ip = bat(
                            script: 'terraform output -raw ec2_public_ip',
                            returnStdout: true
                        ).trim()

                        if (!ip || ip == 'null') {
                            error("Terraform did not return a valid EC2 public IP. Got: '${ip}'")
                        }

                        env.EC2_HOST = ip

                        echo "=========================================="
                        echo "EC2 Public IP: ${env.EC2_HOST}"
                        echo "=========================================="
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

                    withCredentials([
                        sshUserPrivateKey(
                            credentialsId: 'cicd-key',
                            keyFileVariable: 'SSH_KEY',
                            usernameVariable: 'SSH_USER'
                        )
                    ]) {

                        bat """
                            echo Waiting for SSH on %SSH_USER%@${env.EC2_HOST}...

                            set SSH_READY=0

                            for /L %%i in (1,1,30) do (
                                echo SSH attempt %%i of 30...

                                ssh -i "%SSH_KEY%" ^
                                  -o StrictHostKeyChecking=no ^
                                  -o UserKnownHostsFile=NUL ^
                                  -o ConnectTimeout=10 ^
                                  %SSH_USER%@${env.EC2_HOST} "echo SSH_READY" > ssh-test.txt 2>&1

                                if not errorlevel 1 (
                                    echo SSH connection successful.
                                    set SSH_READY=1
                                    goto ssh_done
                                )

                                timeout /t 10 /nobreak >nul
                            )

                            :ssh_done

                            if "%SSH_READY%"=="0" (
                                echo SSH connection failed after 30 attempts.
                                type ssh-test.txt
                                exit /b 1
                            )
                        """
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
                            echo Deploying to EC2: ${env.EC2_HOST}

                            ssh -i "%SSH_KEY%" ^
                              -o StrictHostKeyChecking=no ^
                              -o UserKnownHostsFile=NUL ^
                              %SSH_USER%@${env.EC2_HOST} ^
                              "docker --version"

                            ssh -i "%SSH_KEY%" ^
                              -o StrictHostKeyChecking=no ^
                              -o UserKnownHostsFile=NUL ^
                              %SSH_USER%@${env.EC2_HOST} ^
                              "echo %DOCKER_PASS% | docker login -u %DOCKER_USER% --password-stdin"

                            ssh -i "%SSH_KEY%" ^
                              -o StrictHostKeyChecking=no ^
                              -o UserKnownHostsFile=NUL ^
                              %SSH_USER%@${env.EC2_HOST} ^
                              "docker pull %DOCKER_IMAGE%:%DOCKER_LATEST%"

                            ssh -i "%SSH_KEY%" ^
                              -o StrictHostKeyChecking=no ^
                              -o UserKnownHostsFile=NUL ^
                              %SSH_USER%@${env.EC2_HOST} ^
                              "docker rm -f cicd-demo-app 2> /dev/null || true"

                            ssh -i "%SSH_KEY%" ^
                              -o StrictHostKeyChecking=no ^
                              -o UserKnownHostsFile=NUL ^
                              %SSH_USER%@${env.EC2_HOST} ^
                              "docker run -d --restart unless-stopped --name cicd-demo-app -p 5000:5000 %DOCKER_IMAGE%:%DOCKER_LATEST%"

                            echo.
                            echo ==========================================
                            echo DEPLOYMENT COMPLETED
                            echo Application URL:
                            echo http://${env.EC2_HOST}:5000
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
                    bat """
                        echo Checking application:
                        echo http://${env.EC2_HOST}:5000/

                        powershell -NoProfile -Command ^
                          "\$ok = \$false;" ^
                          "for (\$i = 1; \$i -le 30; \$i++) {" ^
                          "  try {" ^
                          "    \$r = Invoke-WebRequest -Uri 'http://${env.EC2_HOST}:5000/' -UseBasicParsing -TimeoutSec 10;" ^
                          "    if (\$r.StatusCode -eq 200) {" ^
                          "      Write-Host 'HEALTH CHECK PASSED';" ^
                          "      \$ok = \$true;" ^
                          "      break;" ^
                          "    }" ^
                          "  } catch {" ^
                          "    Write-Host ('Waiting for application... attempt ' + \$i);" ^
                          "  }" ^
                          "  Start-Sleep -Seconds 5;" ^
                          "}" ^
                          "if (-not \$ok) { Write-Host 'HEALTH CHECK FAILED'; exit 1 }"
                    """
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
            echo "Docker Image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
            echo "EC2 Host: ${EC2_HOST}"
            echo "Application: http://${EC2_HOST}:5000"
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
