pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = 'your-registry'
        IMAGE_NAME = 'webapp'
        KUBECONFIG = credentials('kubeconfig-id')
        HELM_CHART_PATH = './webapp-chart'
        NAMESPACE = 'webapp-dev'
    }
    
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/your-repo/webapp.git'
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    sh """
                        docker build -t ${DOCKER_REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER} .
                        docker tag ${DOCKER_REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER} ${DOCKER_REGISTRY}/${IMAGE_NAME}:latest
                    """
                }
            }
        }
        
        stage('Push to Registry') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'docker-registry-creds', 
                                                     usernameVariable: 'USER', 
                                                     passwordVariable: 'PASS')]) {
                        sh """
                            echo \$PASS | docker login -u \$USER --password-stdin ${DOCKER_REGISTRY}
                            docker push ${DOCKER_REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER}
                            docker push ${DOCKER_REGISTRY}/${IMAGE_NAME}:latest
                        """
                    }
                }
            }
        }
        
        stage('Helm Lint') {
            steps {
                sh "helm lint ${HELM_CHART_PATH}"
            }
        }
        
        stage('Deploy with Helm') {
            steps {
                script {
                    sh """
                        helm upgrade --install webapp ${HELM_CHART_PATH} \
                          --namespace ${NAMESPACE} \
                          --create-namespace \
                          --set image.tag=${BUILD_NUMBER} \
                          --wait
                    """
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                sh """
                    kubectl get pods -n ${NAMESPACE}
                    kubectl get svc -n ${NAMESPACE}
                """
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
