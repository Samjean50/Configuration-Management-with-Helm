# Configuration Management with Helm — Capstone Project

A DevOps capstone project demonstrating automated Kubernetes deployments using a Jenkins CI/CD pipeline integrated with Helm charts. The project covers infrastructure provisioning with Terraform, Helm chart templating, Jenkins pipeline configuration, and end-to-end deployment automation on AWS.

---

## Architecture Overview

```
Developer (Git Push)
        │
        ▼
GitHub Repository
(Jenkinsfile + Helm Chart + App)
        │
        ▼ (Webhook / Manual Trigger)
Jenkins CI/CD Server (AWS EC2)
  ├── Stage 1: Checkout code
  ├── Stage 2: Configure kubectl
  ├── Stage 3: Lint Helm chart
  ├── Stage 4: Deploy with Helm
  └── Stage 5: Verify deployment
        │
        ▼ (Helm Deploy)
Minikube Kubernetes Cluster (on EC2)
  ├── Deployment (2x Nginx pods)
  └── Service (NodePort :30080)
```

---

## Technologies Used

| Technology | Version | Purpose |
|------------|---------|---------|
| Terraform | 1.x | Infrastructure provisioning |
| AWS EC2 (Ubuntu 24.04) | t3.medium | Cloud compute instance |
| Jenkins | 2.479.3 | CI/CD automation |
| Kubernetes (Minikube) | 1.35.1 | Container orchestration |
| Helm | 3.20.0 | Kubernetes package manager |
| Docker | Latest | Container runtime |
| Nginx | alpine | Web application container |
| Git / GitHub | — | Version control |

---

## Prerequisites

**Local machine:**
- Terraform >= 1.0
- AWS CLI configured (`aws configure`)
- SSH key pair at `~/.ssh/helm-terraform-key`
- Git

**AWS:**
- IAM user with EC2, VPC, and security group permissions
- Security groups allowing ports: `22` (SSH), `8080` (Jenkins), `30080` (NodePort)

**Knowledge:**
- Basic Kubernetes concepts
- Familiarity with Helm charts
- Jenkins pipeline fundamentals

---

## Project Structure

```
Configuration-Management-with-Helm/
├── README.md                    # Project documentation
├── Jenkinsfile                  # Jenkins pipeline definition
├── main.tf                      # Terraform infrastructure
├── variables.tf                 # Terraform variables
├── outputs.tf                   # Terraform outputs
├── install.sh                   # EC2 bootstrap script
└── my-web-app/                  # Helm chart
    ├── Chart.yaml               # Chart metadata
    ├── values.yaml              # Default configuration values
    └── templates/
        ├── _helpers.tpl         # Template helper functions
        ├── deployment.yaml      # Deployment manifest
        ├── service.yaml         # Service manifest
        ├── serviceaccount.yaml  # ServiceAccount manifest
        ├── hpa.yaml             # Horizontal Pod Autoscaler
        ├── ingress.yaml         # Ingress (optional)
        ├── NOTES.txt            # Post-install instructions
        └── tests/
            └── test-connection.yaml
```

---

## Infrastructure Provisioning (Terraform)

### Step 1: Clone the Repository

```bash
git clone https://github.com/Samjean50/Configuration-Management-with-Helm.git
cd Configuration-Management-with-Helm
```

### Step 2: Generate SSH Key

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/helm-terraform-key -N ""
```

### Step 3: Provision EC2 with Terraform

```bash
terraform init
terraform plan
terraform apply -auto-approve

# Note the public IP
terraform output instance_public_ip
```

Terraform provisions:
- VPC (`10.0.0.0/16`) with public subnet in `us-east-1a`
- Internet Gateway and route tables
- Security group with ports 22, 80, 8080, 30080
- `t3.medium` EC2 instance
- Automated installation of Jenkins, Docker, kubectl, Helm, and Minikube

---

## Jenkins Setup and Configuration

### Step 4: Access Jenkins

```bash
# SSH into the instance
ssh -i ~/.ssh/helm-terraform-key ubuntu@<ec2-public-ip>

# Get the initial admin password
cat jenkins-initial-password.txt
```

Open `http://<ec2-public-ip>:8080` in your browser:
1. Enter the admin password
2. Click **Install suggested plugins**
3. Create your admin user
4. Accept the default Jenkins URL

### Step 5: Configure Executors

Go to **Manage Jenkins → System**, set **# of executors** to `5`, and click **Save**.

### Step 6: Install Required Plugins

Navigate to **Manage Jenkins → Plugins → Available plugins** and install:

| Plugin | Purpose |
|--------|---------|
| Git | Source code management |
| Pipeline | Jenkinsfile pipeline execution |
| Workflow Aggregator | Pipeline workflow support |
| GitHub | Webhook integration |
| Pipeline: Stage View | Visual pipeline stages |

### Step 7: Configure Jenkins Security

**Authentication:**
- Go to **Manage Jenkins → Security**
- Security Realm: **Jenkins' own user database**
- Disable "Allow users to sign up"

**Authorisation:**
- Strategy: **Matrix-based security**
- Admin users: full control
- Anonymous users: no access

**Credentials (for private repos):**
- Go to **Manage Jenkins → Credentials → Global → Add Credentials**
- Kind: Username with password
- Use a GitHub Personal Access Token (PAT) as the password
- ID: `github-credentials`

### Step 8: Create the Pipeline Job

1. Click **New Item** → name it `Helm-integration` → select **Pipeline**
2. Under **Pipeline**:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://github.com/Samjean50/Configuration-Management-with-Helm.git`
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`
3. Click **Save**

### Step 9: Configure Kubernetes Access for Jenkins

SSH into the EC2 instance and run:

```bash
# Copy Minikube certificates to Jenkins directory
sudo mkdir -p /var/lib/jenkins/.minikube/profiles/minikube
sudo cp /home/ubuntu/.minikube/ca.crt /var/lib/jenkins/.minikube/
sudo cp /home/ubuntu/.minikube/profiles/minikube/client.crt /var/lib/jenkins/.minikube/profiles/minikube/
sudo cp /home/ubuntu/.minikube/profiles/minikube/client.key /var/lib/jenkins/.minikube/profiles/minikube/
sudo chown -R jenkins:jenkins /var/lib/jenkins/.minikube

# Create kubeconfig for Jenkins
MINIKUBE_IP=$(minikube ip)
sudo -u jenkins bash << EOF
mkdir -p /var/lib/jenkins/.kube
cat > /var/lib/jenkins/.kube/config << KUBECONFIG
apiVersion: v1
clusters:
- cluster:
    certificate-authority: /var/lib/jenkins/.minikube/ca.crt
    server: https://$MINIKUBE_IP:8443
  name: minikube
contexts:
- context:
    cluster: minikube
    user: minikube
  name: minikube
current-context: minikube
kind: Config
preferences: {}
users:
- name: minikube
  user:
    client-certificate: /var/lib/jenkins/.minikube/profiles/minikube/client.crt
    client-key: /var/lib/jenkins/.minikube/profiles/minikube/client.key
KUBECONFIG
chmod 600 /var/lib/jenkins/.kube/config
EOF

# Verify
sudo -u jenkins kubectl get nodes
```

---

## Helm Chart Documentation

### Chart Structure

```
my-web-app/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── _helpers.tpl
    ├── deployment.yaml
    ├── service.yaml
    ├── serviceaccount.yaml
    ├── hpa.yaml
    ├── ingress.yaml
    ├── NOTES.txt
    └── tests/
        └── test-connection.yaml
```

### `Chart.yaml`

```yaml
apiVersion: v2           # Helm 3 API version
name: my-web-app
description: A Helm chart for a Kubernetes web application
type: application        # "application" for deployable apps
version: 0.1.0           # Chart version (SemVer)
appVersion: "1.0"        # Version of the app being packaged
```

### `values.yaml` — Configuration Reference

```yaml
# Replica count
replicaCount: 2

# Container image
image:
  repository: nginx
  pullPolicy: IfNotPresent
  tag: "alpine"

# Service
service:
  type: NodePort         # ClusterIP | NodePort | LoadBalancer
  port: 80
  nodePort: 30080        # Must be in range 30000–32767

# Resource limits
resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi

# Horizontal Pod Autoscaler (disabled by default)
autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

# ServiceAccount
serviceAccount:
  create: true
  automount: true
  annotations: {}
  name: ""
```

### Values Customisation Examples

**Production — high availability:**
```yaml
replicaCount: 5
image:
  tag: "stable"
  pullPolicy: Always
service:
  type: LoadBalancer
resources:
  limits:
    cpu: 500m
    memory: 512Mi
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70
```

**Development — minimal resources:**
```yaml
replicaCount: 1
image:
  tag: "latest"
service:
  type: ClusterIP
ingress:
  enabled: true
  hosts:
    - host: dev.myapp.local
      paths:
        - path: /
          pathType: Prefix
```

### Key Template Explanations

**`deployment.yaml`** uses Helm templating to inject values dynamically:
```yaml
replicas: {{ .Values.replicaCount }}
image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
```

**`service.yaml`** conditionally sets NodePort only when the service type requires it:
```yaml
{{- if and (eq .Values.service.type "NodePort") .Values.service.nodePort }}
nodePort: {{ .Values.service.nodePort }}
{{- end }}
```

**`serviceaccount.yaml`** is conditionally created based on values:
```yaml
{{- if .Values.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
...
{{- end }}
```

**`_helpers.tpl`** provides reusable functions to keep templates DRY:
```yaml
{{- define "my-web-app.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
```

---

## CI/CD Pipeline Documentation

### Jenkinsfile

```groovy
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
                    kubectl config use-context minikube
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
                    helm list
                    kubectl get pods
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
            sh '''
                export KUBECONFIG=/var/lib/jenkins/.kube/config
                helm rollback my-release --wait || true
            '''
        }
    }
}
```

### Pipeline Stage Summary

| Stage | What it does | Success indicator |
|-------|-------------|-------------------|
| Checkout | Clones repo from GitHub | Latest commit checked out |
| Setup Kubectl | Switches to Minikube context | Node shows `Ready` |
| Lint Helm Chart | Validates chart syntax | `0 chart(s) failed` |
| Deploy with Helm | Runs `helm upgrade --install` | `STATUS: deployed` |
| Verify Deployment | Checks pods and services | All pods `1/1 Running` |

### Rollback

Helm maintains full release history, making rollbacks straightforward:

```bash
# View release history
helm history my-release

# Roll back to the previous revision
helm rollback my-release

# Roll back to a specific revision
helm rollback my-release 1

# Verify rollback
kubectl get pods
helm list
```

---

## Usage

### Deploy via Jenkins

1. Go to Jenkins Dashboard → **Helm-integration**
2. Click **Build Now**
3. Monitor progress in **Console Output**

### Deploy Manually

```bash
ssh -i ~/.ssh/helm-terraform-key ubuntu@<ec2-public-ip>
cd Configuration-Management-with-Helm

# Lint
helm lint my-web-app

# Deploy
helm upgrade --install my-release ./my-web-app \
  --namespace default \
  --set replicaCount=2 \
  --wait

# Verify
kubectl get pods
kubectl get svc
helm list
```

### Access the Application

**From the EC2 instance (NodePort):**
```bash
minikube service my-release-my-web-app --url
curl $(minikube service my-release-my-web-app --url)
```

**Via port-forward:**
```bash
kubectl port-forward service/my-release-my-web-app 8080:80
# Visit http://localhost:8080
```

**SSH tunnel from your local machine:**
```bash
ssh -i ~/.ssh/helm-terraform-key -L 30080:192.168.49.2:30080 ubuntu@<ec2-public-ip>
# Visit http://localhost:30080
```

### Common Helm Commands

```bash
# Preview rendered templates without deploying
helm template my-release ./my-web-app

# Override values at deploy time
helm upgrade my-release ./my-web-app --set replicaCount=5

# Use a custom values file
helm upgrade my-release ./my-web-app -f custom-values.yaml

# View deployed values
helm get values my-release

# View rendered manifests
helm get manifest my-release

# Uninstall
helm uninstall my-release
```

---

## Troubleshooting

### Jenkins executor offline / disk full

```bash
sudo docker system prune -a -f --volumes
sudo apt clean
sudo journalctl --vacuum-time=1d
sudo rm -rf /var/lib/jenkins/workspace/*
df -h
```

### kubectl: unable to read client-cert

```bash
# Recopy certificates and fix ownership
sudo cp /home/ubuntu/.minikube/ca.crt /var/lib/jenkins/.minikube/
sudo cp /home/ubuntu/.minikube/profiles/minikube/client.crt /var/lib/jenkins/.minikube/profiles/minikube/
sudo cp /home/ubuntu/.minikube/profiles/minikube/client.key /var/lib/jenkins/.minikube/profiles/minikube/
sudo chown -R jenkins:jenkins /var/lib/jenkins/.minikube

# Test
sudo -u jenkins kubectl get nodes
```

### Pods stuck in `ImagePullBackOff`

```bash
eval $(minikube docker-env)
docker pull nginx:alpine
helm uninstall my-release
helm install my-release ./my-web-app
```

### Pods stuck in `Pending`

```bash
# Describe the pod to find the reason
kubectl describe pod <pod-name>

# If insufficient resources, recreate Minikube with more memory
minikube delete
minikube start --cpus=2 --memory=4096 --driver=docker
```

### Minikube won't start

```bash
sudo systemctl restart docker
minikube delete
minikube start --cpus=2 --memory=4096 --driver=docker
kubectl get nodes
```

### Helm lint failures

```bash
# Always lint locally before pushing
helm lint my-web-app

# Preview rendered output
helm template my-release ./my-web-app

# Common cause: incorrect YAML indentation
# BAD:
image:
  repository: nginx
    pullPolicy: IfNotPresent   # extra indent

# GOOD:
image:
  repository: nginx
  pullPolicy: IfNotPresent
```

---

## Security Considerations

- SSH access is key-based only — no password authentication
- Jenkins is protected with user authentication and matrix-based authorisation
- Kubernetes pods use service accounts with minimal required permissions
- Security groups restrict inbound traffic to required ports only
- Container images use official, minimal Alpine-based variants
- Credentials stored as Jenkins secrets, never hardcoded in the pipeline
- **Future improvement:** Integrate Sealed Secrets or AWS Secrets Manager for Kubernetes secret management

---

## Future Enhancements

**Short-term:**
- GitHub webhook for automatic pipeline triggering on push
- Separate `values-dev.yaml`, `values-staging.yaml`, `values-prod.yaml` per environment
- Helm test automation and smoke tests post-deployment
- Slack or email notifications on pipeline success/failure

**Longer-term:**
- Migrate from Minikube to a production EKS cluster
- Blue-green and canary deployment strategies
- GitOps with ArgoCD for declarative continuous deployment
- Prometheus + Grafana observability stack
- Container image scanning with Trivy in the CI pipeline
- Velero for Kubernetes backup and disaster recovery

---

## Project Deliverables Checklist

| Deliverable | Status |
|-------------|--------|
| README with architecture and setup guide | ✅ |
| Terraform infrastructure (`main.tf`, `variables.tf`, `outputs.tf`) | ✅ |
| Helm chart (`Chart.yaml`, `values.yaml`, templates) | ✅ |
| Jenkinsfile with 5-stage pipeline | ✅ |
| Automated rollback on failure | ✅ |
| Security group and SSH configuration | ✅ |
| Troubleshooting guide | ✅ |

---

## Author

**Samson Bakare**  
DevOps Engineer | AWS | Kubernetes | Terraform | Helm | Jenkins  
[GitHub: Samjean50](https://github.com/Samjean50)
