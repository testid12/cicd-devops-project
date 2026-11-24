// -----------------------------------------------------------------------
// Jenkinsfile - Automated CI/CD Pipeline
// Jenkins, Docker, Terraform, AWS
// Windows Jenkins Agent version
// -----------------------------------------------------------------------
//
// Required Jenkins credentials:
//   dockerhub-creds -> Username/Password
//   aws-creds       -> AWS credentials
//   ec2-ssh-key     -> SSH Username with private key
//   github-creds    -> Optional, only if GitHub repo is private
//
// Required Jenkins plugins:
//   Pipeline
//   Docker Pipeline
//   Credentials Binding
//   AWS Credentials
//   SSH Agent
//   Git
//   JUnit
//   HTML Publisher
// -----------------------------------------------------------------------

pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '15'))
        timeout(time: 45, unit: 'MINUTES')
    }

    environment {
<<<<<<< HEAD
        // ---------------------------------------------------------------
        // USER SETTINGS
        // ---------------------------------------------------------------
        DOCKERHUB_USERNAME = 'princeydv77'
        DOCKER_IMAGE_NAME  = "${DOCKERHUB_USERNAME}/cicd-demo-app"

        AWS_REGION         = 'ap-south-1'
        EC2_SSH_USER       = 'ubuntu'

        // Docker Hub credentials
=======
        // ---- USER MUST EDIT THESE VALUES ----
        DOCKERHUB_USERNAME = 'YOUR_DOCKERHUB_USERNAME'
        DOCKER_IMAGE_NAME  = "${DOCKERHUB_USERNAME}/cicd-demo-app"
        AWS_REGION         = 'ap-south-1'
        EC2_SSH_USER       = 'ubuntu'
        // --------------------------------------

        IMAGE_TAG   = "${env.BUILD_NUMBER}-${env.GIT_COMMIT?.take(7) ?: 'local'}"
>>>>>>> ab153f78c9fcb5cb05e92437ecbf325d0c4f40ff
        DOCKER_CREDS = credentials('dockerhub-creds')
    }

    stages {

<<<<<<< HEAD
        // ===============================================================
        // CHECKOUT
        // ===============================================================

        stage('Checkout') {
            steps {
                echo "==> Cloning repository"

                checkout scm

                script {
                    env.GIT_COMMIT_SHORT = bat(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()

                    env.IMAGE_TAG =
                        "${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"

                    echo "Git Commit: ${env.GIT_COMMIT_SHORT}"
                    echo "Docker Image Tag: ${env.IMAGE_TAG}"
=======
        stage('Checkout') {
            steps {
                echo "==> Cloning repository"
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
>>>>>>> ab153f78c9fcb5cb05e92437ecbf325d0c4f40ff
                }
            }
        }

<<<<<<< HEAD
        // ===============================================================
        // BUILD
        // ===============================================================

        stage('Build') {
            steps {
                echo "==> Installing dependencies and building the app"

                bat '''
                    python --version

                    if not exist .venv (
                        python -m venv .venv
                    )

                    .venv\\Scripts\\python.exe -m pip install --upgrade pip

                    .venv\\Scripts\\python.exe -m pip install -r app\\requirements-dev.txt
=======
        stage('Build') {
            steps {
                echo "==> Installing dependencies and building the app"
                sh '''
                    python3 -m venv .venv
                    . .venv/bin/activate
                    pip install --upgrade pip
                    pip install -r app/requirements-dev.txt
>>>>>>> ab153f78c9fcb5cb05e92437ecbf325d0c4f40ff
                '''
            }
        }

<<<<<<< HEAD
        // ===============================================================
        // TEST
        // ===============================================================

        stage('Test') {
            steps {
                echo "==> Running automated tests"

                bat '''
                    .venv\\Scripts\\python.exe -m pytest app\\tests ^
                        --junitxml=test-results.xml ^
                        --cov=app ^
                        --cov-report=xml
                '''
            }

            post {
                always {
                    junit(
                        testResults: 'test-results.xml',
                        allowEmptyResults: true
                    )
=======
        stage('Test') {
            steps {
                echo "==> Running automated tests"
                sh '''
                    . .venv/bin/activate
                    pytest app/tests --junitxml=test-results.xml --cov=app --cov-report=xml
                '''
            }
            post {
                always {
                    junit 'test-results.xml'
>>>>>>> ab153f78c9fcb5cb05e92437ecbf325d0c4f40ff
                }
            }
        }

<<<<<<< HEAD
        // ===============================================================
        // CODE QUALITY
        // ===============================================================

        stage('Code Quality') {
            steps {
                echo "==> Running SonarQube analysis"

                script {

                    withSonarQubeEnv('sonarqube-server') {

                        bat '''
                            .venv\\Scripts\\python.exe -m pip install flake8

                            .venv\\Scripts\\python.exe -m flake8 app ^
                                --max-line-length=120 ^
                                --exit-zero ^
                                > flake8-report.txt

                            sonar-scanner.bat ^
                                -Dsonar.projectKey=cicd-devops-project ^
                                -Dsonar.sources=app ^
                                -Dsonar.python.version=3.12 ^
                                -Dsonar.python.coverage.reportPaths=coverage.xml
=======
        stage('Code Quality') {
            steps {
                echo "==> Running SonarQube analysis"
                script {
                    // Requires SonarQube Scanner plugin + a configured
                    // SonarQube server named 'sonarqube-server' in
                    // Manage Jenkins > System.
                    withSonarQubeEnv('sonarqube-server') {
                        sh '''
                            . .venv/bin/activate
                            pip install flake8
                            flake8 app --max-line-length=120 --exit-zero > flake8-report.txt || true
                            sonar-scanner \
                              -Dsonar.projectKey=cicd-devops-project \
                              -Dsonar.sources=app \
                              -Dsonar.python.version=3.12 \
                              -Dsonar.python.coverage.reportPaths=coverage.xml
>>>>>>> ab153f78c9fcb5cb05e92437ecbf325d0c4f40ff
                        '''
                    }
                }
            }
        }

<<<<<<< HEAD
        // ===============================================================
        // DOCKER BUILD
        // ===============================================================

        stage('Docker Build') {
            steps {
                echo "==> Building Docker image"

                bat '''
                    docker build ^
                        --build-arg APP_VERSION=%IMAGE_TAG% ^
                        --build-arg BUILD_NUMBER=%BUILD_NUMBER% ^
                        --build-arg GIT_COMMIT=%GIT_COMMIT_SHORT% ^
                        -t %DOCKER_IMAGE_NAME%:%IMAGE_TAG% ^
                        -t %DOCKER_IMAGE_NAME%:latest ^
                        .
=======
        stage('Docker Build') {
            steps {
                echo "==> Building Docker image"
                sh '''
                    docker build \
                      --build-arg APP_VERSION=${IMAGE_TAG} \
                      --build-arg BUILD_NUMBER=${BUILD_NUMBER} \
                      --build-arg GIT_COMMIT=${GIT_COMMIT_SHORT} \
                      -t ${DOCKER_IMAGE_NAME}:${IMAGE_TAG} \
                      -t ${DOCKER_IMAGE_NAME}:latest \
                      .
>>>>>>> ab153f78c9fcb5cb05e92437ecbf325d0c4f40ff
                '''
            }
        }

<<<<<<< HEAD
        // ===============================================================
        // SECURITY SCAN
        // ===============================================================

        stage('Security Scan') {
            steps {
                echo "==> Scanning image with Trivy"

                bat '''
                    where trivy

                    if %ERRORLEVEL% NEQ 0 (
                        echo.
                        echo ERROR: Trivy is not installed or not available in PATH.
                        echo Install Trivy on the Jenkins Windows machine.
                        exit /b 1
                    )

                    trivy image ^
                        --severity HIGH,CRITICAL ^
                        --exit-code 0 ^
                        --format table ^
                        -o trivy-report.txt ^
                        %DOCKER_IMAGE_NAME%:%IMAGE_TAG%

                    type trivy-report.txt
                '''
            }
        }

        // ===============================================================
        // DOCKER PUSH
        // ===============================================================

        stage('Docker Push') {
            steps {
                echo "==> Pushing image to Docker Hub"

                bat '''
                    echo %DOCKER_CREDS_PSW% | docker login ^
                        -u %DOCKER_CREDS_USR% ^
                        --password-stdin

                    docker push %DOCKER_IMAGE_NAME%:%IMAGE_TAG%

                    docker push %DOCKER_IMAGE_NAME%:latest

=======
        stage('Security Scan') {
            steps {
                echo "==> Scanning image with Trivy"
                sh '''
                    if ! command -v trivy &> /dev/null; then
                        echo "Trivy not found, installing..."
                        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
                    fi
                    trivy image --severity HIGH,CRITICAL --exit-code 0 \
                      --format table -o trivy-report.txt ${DOCKER_IMAGE_NAME}:${IMAGE_TAG}
                    cat trivy-report.txt
                '''
                // exit-code is 0 (non-blocking) here for demo purposes.
                // Set --exit-code 1 to fail the build on HIGH/CRITICAL CVEs.
            }
        }

        stage('Docker Push') {
            steps {
                echo "==> Pushing image to Docker Hub"
                sh '''
                    echo "${DOCKER_CREDS_PSW}" | docker login -u "${DOCKER_CREDS_USR}" --password-stdin
                    docker push ${DOCKER_IMAGE_NAME}:${IMAGE_TAG}
                    docker push ${DOCKER_IMAGE_NAME}:latest
>>>>>>> ab153f78c9fcb5cb05e92437ecbf325d0c4f40ff
                    docker logout
                '''
            }
        }

<<<<<<< HEAD
        // ===============================================================
        // TERRAFORM INIT
        // ===============================================================

        stage('Terraform Init') {
            steps {

                dir('terraform') {

                    withCredentials([
                        [
                            $class: 'AmazonWebServicesCredentialsBinding',
                            credentialsId: 'aws-creds'
                        ]
                    ]) {

                        bat '''
                            terraform init -input=false
                        '''
=======
        stage('Terraform Init') {
            steps {
                dir('terraform') {
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']
                    ]) {
                        sh 'terraform init -input=false'
>>>>>>> ab153f78c9fcb5cb05e92437ecbf325d0c4f40ff
                    }
                }
            }
        }

<<<<<<< HEAD
        // ===============================================================
        // TERRAFORM VALIDATE
        // ===============================================================

        stage('Terraform Validate') {
            steps {

                dir('terraform') {

                    bat '''
                        terraform validate
                    '''
=======
        stage('Terraform Validate') {
            steps {
                dir('terraform') {
                    sh 'terraform validate'
>>>>>>> ab153f78c9fcb5cb05e92437ecbf325d0c4f40ff
                }
            }
        }

<<<<<<< HEAD
        // ===============================================================
        // TERRAFORM PLAN
        // ===============================================================

        stage('Terraform Plan') {
            steps {

                dir('terraform') {

                    withCredentials([
                        [
                            $class: 'AmazonWebServicesCredentialsBinding',
                            credentialsId: 'aws-creds'
                        ]
                    ]) {

                        bat '''
                            terraform plan ^
                                -input=false ^
                                -var="docker_image=%DOCKER_IMAGE_NAME%:%IMAGE_TAG%" ^
                                -out=tfplan
=======
        stage('Terraform Plan') {
            steps {
                dir('terraform') {
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']
                    ]) {
                        sh '''
                            terraform plan -input=false \
                              -var="docker_image=${DOCKER_IMAGE_NAME}:${IMAGE_TAG}" \
                              -out=tfplan
>>>>>>> ab153f78c9fcb5cb05e92437ecbf325d0c4f40ff
                        '''
                    }
                }
            }
        }

<<<<<<< HEAD
        // ===============================================================
        // TERRAFORM APPLY
        // ===============================================================

        stage('Terraform Apply') {
            steps {

                dir('terraform') {

                    withCredentials([
                        [
                            $class: 'AmazonWebServicesCredentialsBinding',
                            credentialsId: 'aws-creds'
                        ]
                    ]) {

                        bat '''
                            terraform apply ^
                                -input=false ^
                                -auto-approve ^
                                tfplan
                        '''

                        script {

                            env.EC2_PUBLIC_IP = bat(
                                script: 'terraform output -raw ec2_public_ip',
                                returnStdout: true
                            ).trim()

                            echo "EC2 Public IP: ${env.EC2_PUBLIC_IP}"
=======
        stage('Terraform Apply') {
            steps {
                dir('terraform') {
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']
                    ]) {
                        sh 'terraform apply -input=false -auto-approve tfplan'
                        script {
                            env.EC2_PUBLIC_IP = sh(script: "terraform output -raw ec2_public_ip", returnStdout: true).trim()
>>>>>>> ab153f78c9fcb5cb05e92437ecbf325d0c4f40ff
                        }
                    }
                }
            }
        }

<<<<<<< HEAD
        // ===============================================================
        // DEPLOY
        // ===============================================================

        stage('Deploy') {
            steps {

                echo "==> Deploying new image to EC2 (${env.EC2_PUBLIC_IP})"

                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'ec2-ssh-key',
                        keyFileVariable: 'SSH_KEY'
                    )
                ]) {

                    bat '''
                        echo.
                        echo ==> Copying deployment script to EC2...

                        scp -i "%SSH_KEY%" ^
                            -o StrictHostKeyChecking=no ^
                            scripts\\deploy.sh ^
                            %EC2_SSH_USER%@%EC2_PUBLIC_IP%:/tmp/deploy.sh

                        echo.
                        echo ==> Executing deployment script on EC2...

                        ssh -i "%SSH_KEY%" ^
                            -o StrictHostKeyChecking=no ^
                            %EC2_SSH_USER%@%EC2_PUBLIC_IP% ^
                            "chmod +x /tmp/deploy.sh && /tmp/deploy.sh %DOCKER_IMAGE_NAME%:%IMAGE_TAG%"
=======
        stage('Deploy') {
            steps {
                echo "==> Deploying new image to EC2 (${env.EC2_PUBLIC_IP})"
                withCredentials([
                    sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'SSH_KEY')
                ]) {
                    sh '''
                        chmod 600 "$SSH_KEY"
                        scp -i "$SSH_KEY" -o StrictHostKeyChecking=no scripts/deploy.sh ${EC2_SSH_USER}@${EC2_PUBLIC_IP}:/tmp/deploy.sh
                        ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ${EC2_SSH_USER}@${EC2_PUBLIC_IP} \
                          "chmod +x /tmp/deploy.sh && /tmp/deploy.sh ${DOCKER_IMAGE_NAME}:${IMAGE_TAG}"
>>>>>>> ab153f78c9fcb5cb05e92437ecbf325d0c4f40ff
                    '''
                }
            }
        }

<<<<<<< HEAD
        // ===============================================================
        // HEALTH CHECK
        // ===============================================================

        stage('Health Check') {
            steps {

                echo "==> Verifying application health"

                script {

                    bat '''
                        echo Checking application health...

                        curl.exe --fail ^
                            --max-time 30 ^
                            http://%EC2_PUBLIC_IP%:5000/health
                    '''
                }
=======
        stage('Health Check') {
            steps {
                echo "==> Verifying application health"
                sh '''
                    chmod +x scripts/health-check.sh
                    ./scripts/health-check.sh http://${EC2_PUBLIC_IP}:5000/health
                '''
>>>>>>> ab153f78c9fcb5cb05e92437ecbf325d0c4f40ff
            }
        }
    }

<<<<<<< HEAD
    // ===================================================================
    // POST ACTIONS
    // ===================================================================

    post {

        success {
            echo "================================================="
            echo "Pipeline succeeded!"
            echo "App deployed at: http://${env.EC2_PUBLIC_IP}:5000"
            echo "================================================="
        }

        failure {
            echo "================================================="
            echo "Pipeline failed."
            echo "Check the stage logs above for details."
            echo "================================================="
        }

        always {

            echo "==> Cleaning workspace"

            // Windows Jenkins agent
            bat '''
                docker image prune -f
            '''

            cleanWs()
        }
    }
}
=======
    post {
        success {
            echo "✅ Pipeline succeeded! App deployed at: http://${env.EC2_PUBLIC_IP}:5000"
        }
        failure {
            echo "❌ Pipeline failed. Check the stage logs above for details."
        }
        always {
            echo "==> Cleaning workspace"
            sh 'docker image prune -f || true'
            cleanWs()
        }
    }
}
>>>>>>> ab153f78c9fcb5cb05e92437ecbf325d0c4f40ff
