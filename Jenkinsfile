pipeline {
    agent any

    options {
        timestamps()
        timeout(time: 45, unit: 'MINUTES')
        skipDefaultCheckout(true)
    }

    environment {
        DOCKER_IMAGE = 'princeydv77/cicd-demo-app'
        DOCKER_CREDS = credentials('dockerhub-test')
        AWS_CREDS_ID = 'aws-creds'
        SSH_CREDS_ID = 'cicd-key'
        SONAR_TOKEN = credentials('sonarqube-token')
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
                          -Dsonar.tests=app/tests ^
                          -Dsonar.exclusions=app/tests/** ^
                          -Dsonar.test.inclusions=app/tests/** ^
                          -Dsonar.python.version=3.11 ^
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
                    trivy fs --exit-code 0 --severity HIGH,CRITICAL --ignore-unfixed .
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

                        powershell -NoProfile -Command "$auth = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('%DOCKER_USER%:%DOCKER_PASS%')); $json = '{\"auths\":{\"https://index.docker.io/v1/\":{\"auth\":\"' + $auth + '\"},\"https://registry-1.docker.io/v2/\":{\"auth\":\"' + $auth + '\"}}}'; Set-Content -Path '%WORKSPACE%\\.docker\\config.json' -Value $json"

                        set "DOCKER_CONFIG=%WORKSPACE%\\.docker"

                        docker push %DOCKER_IMAGE%:%BUILD_NUMBER%
                        docker push %DOCKER_IMAGE%:latest
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
                            terraform init -upgrade
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

        stage('Terraform Import Existing IAM') {
            steps {
                echo '=========================================='
                echo ' STEP 11: TERRAFORM IMPORT EXISTING IAM'
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
                        error("Could not obtain EC2 public IP from Terraform output. Value: '${ip}'")
                    }

                    env.EC2_HOST = ip
                    echo "EC2 Public IP: ${env.EC2_HOST}"
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
                        error('EC2_HOST is empty')
                    }
                }

                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'cicd-key',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    bat '''
                        powershell -NoProfile -Command "$ok = $false; for ($i = 1; $i -le 12; $i++) { Write-Host ('SSH check attempt ' + $i + ' of 12'); ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i '%SSH_KEY%' %SSH_USER%@%EC2_HOST% 'echo SSH_READY' 2>$null; if ($LASTEXITCODE -eq 0) { $ok = $true; break }; Write-Host 'SSH not ready yet'; Start-Sleep -Seconds 10 }; if (-not $ok) { exit 1 }"
                    '''
                }
            }
        }

        stage('Deploy') {
            steps {
                echo '=========================================='
                echo ' STEP 15: DEPLOY'
                echo '=========================================='

                script {
                    if (!env.EC2_HOST?.trim()) {
                        error('EC2_HOST is empty')
                    }
                }

                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'cicd-key',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    bat '''
                        powershell -NoProfile -Command "$remote = @'
set -e
echo '=========================================='
echo ' Deploying application'
echo '=========================================='

sudo docker pull %DOCKER_IMAGE%:latest

sudo docker rm -f cicd-demo-app 2>/dev/null || true

sudo docker run -d `
  --name cicd-demo-app `
  --restart unless-stopped `
  -p 5000:5000 `
  %DOCKER_IMAGE%:latest

sleep 5

sudo docker ps --filter 'name=cicd-demo-app'
'@; Set-Content -Path '%WORKSPACE%\\deploy_remote.sh' -Value $remote"

                        scp -o StrictHostKeyChecking=no -i "%SSH_KEY%" "%WORKSPACE%\\deploy_remote.sh" "%SSH_USER%@%EC2_HOST%:/tmp/deploy_remote.sh"

                        ssh -o StrictHostKeyChecking=no -i "%SSH_KEY%" "%SSH_USER%@%EC2_HOST%" "chmod +x /tmp/deploy_remote.sh && /tmp/deploy_remote.sh"
                    '''
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
                        error('EC2_HOST is empty')
                    }

                    bat """
                        powershell -NoProfile -Command "Start-Sleep -Seconds 10; Write-Host 'Checking application at http://${env.EC2_HOST}:5000/health'; \$ok = \$false; for (\$i = 1; \$i -le 12; \$i++) { try { \$r = Invoke-WebRequest -UseBasicParsing -Uri 'http://${env.EC2_HOST}:5000/health' -TimeoutSec 10; Write-Host ('HTTP Status: ' + \$r.StatusCode); if (\$r.StatusCode -eq 200) { \$ok = \$true; Write-Host 'APPLICATION HEALTH CHECK PASSED'; break } } catch { Write-Host ('Health check attempt ' + \$i + ' failed') }; Start-Sleep -Seconds 10 }; if (-not \$ok) { Write-Host 'APPLICATION HEALTH CHECK FAILED'; exit 1 }"
                    """
                }
            }
        }
    }

    post {
        always {
            bat '''
                if exist "%WORKSPACE%\\.docker\\config.json" del /f /q "%WORKSPACE%\\.docker\\config.json"
                if exist "%WORKSPACE%\\.docker" rmdir "%WORKSPACE%\\.docker" 2>nul
            '''
        }

        success {
            echo ''
            echo '=========================================='
            echo ' CI/CD PIPELINE SUCCESSFUL'
            echo '=========================================='
            echo "Docker Image: ${DOCKER_IMAGE}:latest"
            echo "EC2 Public IP: ${env.EC2_HOST}"
            echo "Application URL: http://${env.EC2_HOST}:5000"
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
    }
}
