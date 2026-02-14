
pipeline {
    agent any
    
    environment {
        DOCKER_IMAGE = "samjean50/web-app"
        HELM_CHART = "./helm-chart"
    }
    
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/Samjean50/Configuration-Management-with-Helm/web-app.git'
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    docker.build("${DOCKER_IMAGE}:${BUILD_NUMBER}")
                }
            }
        }
        
        stage('Push to Registry') {
            steps {
                script {
                    docker.withRegistry('https://registry.hub.docker.com', 'dockerhub-credentials') {
                        docker.image("${DOCKER_IMAGE}:${BUILD_NUMBER}").push()
                        docker.image("${DOCKER_IMAGE}:${BUILD_NUMBER}").push('latest')
                    }
                }
            }
        }
        
        stage('Deploy with Helm') {
            steps {
                script {
                    sh """
                        helm upgrade --install my-app ${HELM_CHART} \
                            --set image.tag=${BUILD_NUMBER} \
                            --namespace default
                    """
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                sh 'kubectl get pods'
                sh 'kubectl get svc'
            }
        }
    }
    
    post {
        success {
            echo 'Deployment successful!'
        }
        failure {
            echo 'Deployment failed!'
        }
    }
}
