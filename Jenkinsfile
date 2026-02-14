pipeline {
    agent any
    
    environment {
        KUBECONFIG = '/var/lib/jenkins/.kube/config'
    }
    
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/Samjean50/Configuration-Management-with-Helm.git'
            }
        }
        
        stage('Verify Tools') {
            steps {
                sh '''
                    echo "Checking required tools..."
                    helm version
                    kubectl version --client
                    kubectl get nodes
                '''
            }
        }
        
        stage('Lint Helm Chart') {
            steps {
                sh 'helm lint my-web-app'
            }
        }
        
        stage('Dry Run Deployment') {
            steps {
                sh '''
                    helm upgrade --install my-release ./my-web-app \
                        --namespace default \
                        --dry-run \
                        --debug
                '''
            }
        }
        
        stage('Deploy with Helm') {
            steps {
                sh '''
                    helm upgrade --install my-release ./my-web-app \
                        --namespace default \
                        --set replicaCount=2 \
                        --wait \
                        --timeout 5m
                '''
            }
        }
        
        stage('Verify Deployment') {
            steps {
                sh '''
                    echo "Checking Helm release status..."
                    helm list
                    
                    echo "Checking pods..."
                    kubectl get pods -l app.kubernetes.io/instance=my-release
                    
                    echo "Checking services..."
                    kubectl get svc my-release-my-web-app
                '''
            }
        }
    }
    
    post {
        success {
            echo '✅ Helm deployment completed successfully!'
        }
        failure {
            echo '❌ Deployment failed! Check the logs above.'
            sh 'helm list'
            sh 'kubectl get pods'
        }
    }
}
