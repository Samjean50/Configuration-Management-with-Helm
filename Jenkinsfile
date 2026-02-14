pipeline {
    agent any
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Setup Kubectl') {
            steps {
                sh '''
                    export KUBECONFIG=/var/lib/jenkins/.kube/config
                    kubectl config use-context minikube || true
                    kubectl get nodes
                '''
            }
        }
        
        stage('Lint Helm Chart') {
            steps {
                sh 'helm lint my-web-app'
            }
        }
        
        stage('Deploy with Helm') {
            steps {
                sh '''
                    export KUBECONFIG=/var/lib/jenkins/.kube/config
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
                    export KUBECONFIG=/var/lib/jenkins/.kube/config
                    echo "Helm releases:"
                    helm list
                    
                    echo "Pods:"
                    kubectl get pods
                    
                    echo "Services:"
                    kubectl get svc
                '''
            }
        }
    }
    
    post {
        success {
            echo '✅ Deployment successful!'
        }
        failure {
            echo '❌ Deployment failed!'
        }
    }
}
