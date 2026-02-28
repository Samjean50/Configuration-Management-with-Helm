# Configuration Management with Helm - Capstone Project

## Project Overview

This capstone project demonstrates the integration of Jenkins CI/CD with Helm for automated Kubernetes deployments. The project showcases configuration management best practices, automated deployment pipelines, and Kubernetes orchestration using Helm charts.

**Key Technologies:**
- Jenkins 2.479.3 (CI/CD automation)
- Helm 3.20.0 (Kubernetes package manager)
- Kubernetes via Minikube (Container orchestration)
- Docker (Containerization)
- Git/GitHub (Version control)

**Project Objectives:**
- Implement a CI/CD pipeline using Jenkins with primary focus on Helm charts
- Automate deployment of a web application to Kubernetes
- Demonstrate understanding of configuration management and infrastructure as code
- Showcase Helm templating and values customization

---

## Table of Contents

1. [Architecture](#architecture)
2. [Prerequisites](#prerequisites)
3. [Installation Guide](#installation-guide)
4. [Jenkins Setup and Configuration](#jenkins-setup-and-configuration)
5. [Helm Chart Documentation](#helm-chart-documentation)
6. [CI/CD Pipeline Documentation](#cicd-pipeline-documentation)
7. [Usage Guide](#usage-guide)
8. [Troubleshooting](#troubleshooting)
9. [Project Structure](#project-structure)
10. [Future Enhancements](#future-enhancements)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Developer                            │
│                    (Git Push to GitHub)                      │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Repository                         │
│         (Jenkinsfile + Helm Chart + Application)            │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼ (Webhook/Poll)
┌─────────────────────────────────────────────────────────────┐
│                   Jenkins CI/CD Server                       │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Pipeline Stages:                                    │   │
│  │  1. Checkout Code from Git                           │   │
│  │  2. Setup Kubectl Context                            │   │
│  │  3. Lint Helm Chart                                  │   │
│  │  4. Deploy with Helm (helm upgrade --install)        │   │
│  │  5. Verify Deployment (kubectl get pods/svc)         │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼ (Helm Deploy)
┌─────────────────────────────────────────────────────────────┐
│              Kubernetes Cluster (Minikube)                   │
│  ┌──────────────────┐      ┌──────────────────┐            │
│  │   Deployment     │      │     Service      │            │
│  │  (2x Nginx Pods) │──────│   (NodePort)     │            │
│  └──────────────────┘      └──────────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### System Requirements
- **Operating System:** Ubuntu 24.04 LTS
- **Instance Type:** AWS EC2 t3.medium (2 vCPU, 4 GB RAM)
- **Storage:** Minimum 20 GB
- **Network:** Security groups allowing ports 22 (SSH), 8080 (Jenkins), 30080 (NodePort)

### Software Requirements
- Java 17 (OpenJDK)
- Docker 20.10+
- Git 2.43+
- kubectl 1.35+
- Helm 3.20+
- Minikube (latest)

---

## Installation Guide

### 1. Infrastructure Setup

#### Provision EC2 Instance with Terraform

```bash
# Clone the repository
git clone https://github.com/Samjean50/Configuration-Management-with-Helm.git
cd Configuration-Management-with-Helm

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply infrastructure
terraform apply -auto-approve

# Note the public IP from outputs
terraform output instance_public_ip
```

**Terraform Configuration Highlights:**
- VPC with custom CIDR (10.0.0.0/16)
- Public subnet in us-east-1a
- Internet Gateway for external access
- Security group with ports 22, 80, 8080, 30080
- t3.medium EC2 instance with automated provisioning

#### Manual Setup (Alternative)

If not using Terraform, manually provision an Ubuntu 24.04 EC2 instance and SSH in:

```bash
ssh -i ~/.ssh/helm-terraform-key ubuntu@<ec2-public-ip>
```

### 2. Install Required Software

#### Install Java

```bash
sudo apt update -y
sudo apt install -y fontconfig openjdk-17-jre

# Verify installation
java -version
```

#### Install Jenkins

```bash
# Download Jenkins package
cd /tmp
wget https://pkg.jenkins.io/debian-stable/binary/jenkins_2.479.3_all.deb

# Install Jenkins
sudo dpkg -i jenkins_2.479.3_all.deb || sudo apt-get install -f -y

# Start and enable Jenkins
sudo systemctl daemon-reload
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Verify Jenkins is running
sudo systemctl status jenkins

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

#### Install Docker

```bash
# Install Docker
sudo apt install -y docker.io

# Add users to docker group
sudo usermod -aG docker ubuntu
sudo usermod -aG docker jenkins

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Verify
docker --version
```

#### Install kubectl

```bash
# Download kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Install
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify
kubectl version --client
```

#### Install Helm

```bash
# Install Helm using official script
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify
helm version
```

#### Install Minikube

```bash
# Download Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64

# Install
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Remove installer
rm minikube-linux-amd64

# Verify
minikube version
```

### 3. Start Minikube Cluster

```bash
# Start Minikube with Docker driver
minikube start --cpus=2 --memory=4096 --driver=docker

# Verify cluster is running
kubectl get nodes

# Expected output:
# NAME       STATUS   ROLES           AGE   VERSION
# minikube   Ready    control-plane   1m    v1.35.0
```

### 4. Configure Minikube Access for Jenkins

```bash
# Copy Minikube certificates to Jenkins directory
sudo mkdir -p /var/lib/jenkins/.minikube/profiles/minikube
sudo cp /home/ubuntu/.minikube/ca.crt /var/lib/jenkins/.minikube/
sudo cp /home/ubuntu/.minikube/profiles/minikube/client.crt /var/lib/jenkins/.minikube/profiles/minikube/
sudo cp /home/ubuntu/.minikube/profiles/minikube/client.key /var/lib/jenkins/.minikube/profiles/minikube/
sudo chown -R jenkins:jenkins /var/lib/jenkins/.minikube

# Get Minikube IP
MINIKUBE_IP=$(minikube ip)

# Create kubeconfig for Jenkins
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

# Test Jenkins can access Kubernetes
sudo -u jenkins kubectl get nodes
```

---

## Jenkins Setup and Configuration

### Initial Jenkins Setup

1. **Access Jenkins Web Interface**
   ```
   http://<ec2-public-ip>:8080
   ```

2. **Unlock Jenkins**
   - Paste the initial admin password from:
     ```bash
     sudo cat /var/lib/jenkins/secrets/initialAdminPassword
     ```

3. **Install Suggested Plugins**
   - Click "Install suggested plugins"
   - Wait for installation to complete

4. **Create Admin User**
   - Username: `admin` (or your preference)
   - Password: Choose a strong password
   - Full name: Your name
   - Email: Your email

5. **Jenkins URL Configuration**
   - Accept the default URL: `http://<ec2-public-ip>:8080/`

### Jenkins Plugins

#### Core Plugins Installed

| Plugin Name | Version | Purpose |
|-------------|---------|---------|
| **Git** | Latest | Source code management, checkout from GitHub |
| **Pipeline** | Latest | Enables Jenkinsfile pipeline execution |
| **Workflow Aggregator** | Latest | Pipeline workflow support |
| **GitHub** | Latest | GitHub webhook integration |
| **Pipeline: Stage View** | Latest | Visual pipeline stage representation |
| **Blue Ocean** (Optional) | Latest | Modern UI for pipeline visualization |
| **Credentials** | Latest | Secure credential management |

#### Plugin Installation

**Via Web Interface:**
1. Navigate to: `Manage Jenkins` → `Plugins` → `Available plugins`
2. Search for each plugin
3. Select and click "Install"
4. Restart Jenkins if required

**Via CLI (Alternative):**
```bash
# Install plugins via Jenkins CLI
java -jar jenkins-cli.jar -s http://localhost:8080/ install-plugin git pipeline workflow-aggregator github
```

### Security Configurations

#### 1. User Authentication and Authorization

**Configure Security Realm:**
- Navigate to: `Manage Jenkins` → `Security`
- **Security Realm:** Jenkins' own user database
- **Allow users to sign up:** Disabled (for production)

**Authorization Strategy:**
- **Strategy:** Matrix-based security
- **Permissions:**
  - Admin users: Full control
  - Authenticated users: Read access
  - Anonymous users: No access

#### 2. CSRF Protection

- Navigate to: `Manage Jenkins` → `Security`
- Enable: **Prevent Cross Site Request Forgery exploits**
- **Crumb Issuer:** Default Crumb Issuer

#### 3. Agent to Controller Security

- Navigate to: `Manage Jenkins` → `Security` → `Agents`
- **Agent → Controller Security:** Enabled
- **TCP port for inbound agents:** Random or Fixed (8443)

#### 4. Script Security

- Navigate to: `Manage Jenkins` → `Security`
- **Script Security for Job DSL:** Enabled
- Only approve scripts from trusted sources

#### 5. Credential Management

**Add GitHub Credentials (if using private repository):**

1. Navigate to: `Manage Jenkins` → `Credentials` → `System` → `Global credentials`
2. Click "Add Credentials"
3. **Kind:** Username with password
4. **Username:** GitHub username
5. **Password:** Personal Access Token (PAT)
6. **ID:** `github-credentials`
7. **Description:** GitHub Access Token

**Best Practices:**
- Use Personal Access Tokens (PAT) instead of passwords
- Limit token scope to necessary permissions only
- Rotate credentials regularly
- Never commit credentials to Git

### System Configuration

#### Configure Executors

1. Navigate to: `Manage Jenkins` → `System`
2. **# of executors:** 5
3. Click "Save"

This allows Jenkins to run multiple builds concurrently.

#### Configure Global Tool Configuration

1. Navigate to: `Manage Jenkins` → `Tools`

**Git:**
- Name: `Default`
- Path to Git executable: `git`

**JDK:**
- Name: `OpenJDK-17`
- JAVA_HOME: `/usr/lib/jvm/java-17-openjdk-amd64`

**Note:** Helm and kubectl are installed system-wide and don't require Jenkins tool configuration.

---

## Helm Chart Documentation

### Chart Structure

```
my-web-app/
├── Chart.yaml              # Chart metadata
├── values.yaml             # Default configuration values
├── charts/                 # Chart dependencies (empty for this project)
└── templates/              # Kubernetes manifest templates
    ├── NOTES.txt           # Usage notes displayed after installation
    ├── _helpers.tpl        # Template helper functions
    ├── deployment.yaml     # Deployment manifest template
    ├── service.yaml        # Service manifest template
    ├── serviceaccount.yaml # ServiceAccount template
    ├── hpa.yaml            # Horizontal Pod Autoscaler template
    ├── ingress.yaml        # Ingress template
    └── tests/
        └── test-connection.yaml  # Helm test pod
```

### Chart.yaml Explanation

```yaml
apiVersion: v2                    # Helm chart API version
name: my-web-app                  # Chart name
description: A Helm chart for Kubernetes web application
type: application                 # Chart type (application or library)
version: 0.1.0                    # Chart version (SemVer)
appVersion: "1.0"                 # Version of the application being deployed
```

**Key Fields:**
- **apiVersion:** Always `v2` for Helm 3
- **name:** Must match the directory name
- **type:** `application` for deployable apps, `library` for reusable templates
- **version:** Chart version, incremented with changes
- **appVersion:** Application version being packaged

### Values.yaml - Configuration Guide

The `values.yaml` file contains all configurable parameters for the Helm chart.

```yaml
# Number of pod replicas
replicaCount: 2

# Container image configuration
image:
  repository: nginx           # Docker image repository
  pullPolicy: IfNotPresent    # Image pull policy
  tag: "alpine"               # Image tag

# Service configuration
service:
  type: NodePort             # Service type: ClusterIP, NodePort, LoadBalancer
  port: 80                   # Service port
  nodePort: 30080            # NodePort (30000-32767 range)

# Ingress configuration
ingress:
  enabled: false             # Enable/disable ingress
  className: "nginx"
  annotations: {}
  hosts:
    - host: chart-example.local
      paths:
        - path: /
          pathType: Prefix
  tls: []

# Resource limits and requests
resources:
  limits:
    cpu: 100m               # Maximum CPU (millicores)
    memory: 128Mi           # Maximum memory
  requests:
    cpu: 50m                # Requested CPU
    memory: 64Mi            # Requested memory

# Horizontal Pod Autoscaler
autoscaling:
  enabled: false            # Enable/disable autoscaling
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

# ServiceAccount configuration
serviceAccount:
  create: true              # Create service account
  automount: true
  annotations: {}
  name: ""                  # Leave empty for auto-generated name
```

### Values Customization Examples

#### Example 1: Production Deployment with High Availability

```yaml
replicaCount: 5

image:
  repository: nginx
  pullPolicy: Always
  tag: "stable"

service:
  type: LoadBalancer
  port: 80

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70
```

#### Example 2: Development/Testing with Ingress

```yaml
replicaCount: 1

image:
  repository: nginx
  pullPolicy: IfNotPresent
  tag: "latest"

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: dev.myapp.local
      paths:
        - path: /
          pathType: Prefix

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

### Template Explanations

#### 1. deployment.yaml

**Purpose:** Defines the Deployment resource that manages pod replicas.

**Key Components:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "my-web-app.fullname" . }}
  labels:
    {{- include "my-web-app.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "my-web-app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "my-web-app.labels" . | nindent 8 }}
    spec:
      serviceAccountName: {{ include "my-web-app.serviceAccountName" . }}
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - name: http
          containerPort: 80
          protocol: TCP
        resources:
          {{- toYaml .Values.resources | nindent 12 }}
```

**Helm Templating Features:**
- `{{ include "function" . }}`: Calls helper functions from `_helpers.tpl`
- `{{ .Values.key }}`: References values from `values.yaml`
- `{{- toYaml .Values.resources | nindent 12 }}`: Converts YAML and indents
- `{{- }}`: Removes whitespace for cleaner output

#### 2. service.yaml

**Purpose:** Exposes the application pods via a Kubernetes Service.

**Key Features:**
- Service type controlled by `.Values.service.type`
- Supports ClusterIP, NodePort, and LoadBalancer
- Automatically selects pods using labels from deployment

```yaml
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
      {{- if and (eq .Values.service.type "NodePort") .Values.service.nodePort }}
      nodePort: {{ .Values.service.nodePort }}
      {{- end }}
  selector:
    {{- include "my-web-app.selectorLabels" . | nindent 4 }}
```

#### 3. serviceaccount.yaml

**Purpose:** Creates a ServiceAccount for the pods (RBAC).

**Conditional Creation:**
```yaml
{{- if .Values.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "my-web-app.serviceAccountName" . }}
  labels:
    {{- include "my-web-app.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
```

**Benefits:**
- Enables RBAC policies
- Allows pods to interact with Kubernetes API
- Can be customized with annotations for cloud IAM roles (AWS IRSA, GCP Workload Identity)

#### 4. hpa.yaml (Horizontal Pod Autoscaler)

**Purpose:** Automatically scales pods based on CPU/memory metrics.

**Key Configuration:**
```yaml
{{- if .Values.autoscaling.enabled }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "my-web-app.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
{{- end }}
```

**Note:** When HPA is enabled, it overrides the static `replicaCount` value.

#### 5. ingress.yaml

**Purpose:** Exposes HTTP/HTTPS routes from outside the cluster.

**Features:**
- Only created if `ingress.enabled: true`
- Supports multiple hosts and paths
- TLS/SSL certificate configuration
- Annotation-based configuration for ingress controllers

#### 6. _helpers.tpl

**Purpose:** Contains reusable template functions (Go template helpers).

**Key Helper Functions:**

```yaml
{{/* Generate full name */}}
{{- define "my-web-app.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Common labels */}}
{{- define "my-web-app.labels" -}}
helm.sh/chart: {{ include "my-web-app.chart" . }}
{{ include "my-web-app.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
```

**Benefits:**
- DRY (Don't Repeat Yourself) principle
- Consistent naming conventions
- Easier maintenance

### Helm Commands Reference

```bash
# Create a new chart
helm create my-web-app

# Lint the chart (validate syntax)
helm lint my-web-app

# Dry-run installation (test without deploying)
helm install my-release ./my-web-app --dry-run --debug

# Install the chart
helm install my-release ./my-web-app

# Upgrade the release
helm upgrade my-release ./my-web-app

# Install or upgrade (idempotent)
helm upgrade --install my-release ./my-web-app

# Override values during installation
helm install my-release ./my-web-app --set replicaCount=5

# Use custom values file
helm install my-release ./my-web-app -f custom-values.yaml

# List releases
helm list

# Get release details
helm get all my-release

# View release history
helm history my-release

# Rollback to previous version
helm rollback my-release

# Rollback to specific revision
helm rollback my-release 2

# Uninstall release
helm uninstall my-release

# Package chart for distribution
helm package my-web-app

# View rendered templates
helm template my-release ./my-web-app
```

---

## CI/CD Pipeline Documentation

### Pipeline Overview

The Jenkins pipeline automates the deployment of the Helm chart to Kubernetes, ensuring consistent and repeatable deployments.

**Pipeline Type:** Declarative Pipeline (Jenkinsfile)
**Source:** GitHub Repository
**Trigger:** Manual (Build Now) or GitHub Webhook

### Jenkinsfile Structure

```groovy
pipeline {
    agent any                    // Run on any available agent
    
    stages {
        stage('Checkout') { }    // Clone repository
        stage('Setup Kubectl') { } // Configure Kubernetes access
        stage('Lint Helm Chart') { } // Validate chart syntax
        stage('Deploy with Helm') { } // Deploy to Kubernetes
        stage('Verify Deployment') { } // Verify pods and services
    }
    
    post {
        success { }              // Actions on success
        failure { }              // Actions on failure
    }
}
```

### Pipeline Stages Breakdown

#### Stage 1: Checkout

**Purpose:** Clone the Git repository containing the Helm chart and application code.

**Configuration:**
```groovy
stage('Checkout') {
    steps {
        checkout scm
    }
}
```

**What Happens:**
1. Jenkins connects to GitHub repository
2. Clones the main branch
3. Checks out the latest commit
4. Places code in Jenkins workspace: `/var/lib/jenkins/workspace/Helm-integration/`

**Output Example:**
```
Cloning repository https://github.com/Samjean50/Configuration-Management-with-Helm.git
Commit: 2788f48 - "Adding all helm files"
```

#### Stage 2: Setup Kubectl

**Purpose:** Configure kubectl to communicate with the Minikube Kubernetes cluster.

**Code:**
```groovy
stage('Setup Kubectl') {
    steps {
        sh '''
            export KUBECONFIG=/var/lib/jenkins/.kube/config
            kubectl config use-context minikube
            kubectl get nodes
        '''
    }
}
```

**What Happens:**
1. Sets `KUBECONFIG` environment variable
2. Switches to Minikube context
3. Verifies cluster connectivity
4. Displays available nodes

**Expected Output:**
```
Switched to context "minikube".
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   2d    v1.35.0
```

**Failure Scenarios:**
- Minikube not running → Pipeline fails
- Certificate permission issues → kubectl cannot authenticate
- Network connectivity issues → Cannot reach Kubernetes API

#### Stage 3: Lint Helm Chart

**Purpose:** Validate Helm chart syntax and structure before deployment.

**Code:**
```groovy
stage('Lint Helm Chart') {
    steps {
        sh 'helm lint my-web-app'
    }
}
```

**What Happens:**
1. Helm examines chart structure
2. Validates YAML syntax
3. Checks for missing required fields
4. Verifies template rendering

**Expected Output:**
```
==> Linting my-web-app
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed
```

**Common Linting Errors:**
- Invalid YAML syntax
- Missing required fields in Chart.yaml
- Template rendering errors
- Incorrect indentation

#### Stage 4: Deploy with Helm

**Purpose:** Deploy or upgrade the application using Helm.

**Code:**
```groovy
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
```

**Command Breakdown:**

| Flag | Purpose |
|------|---------|
| `upgrade --install` | Install if new, upgrade if exists (idempotent) |
| `my-release` | Release name |
| `./my-web-app` | Path to Helm chart |
| `--namespace default` | Target Kubernetes namespace |
| `--set replicaCount=2` | Override values.yaml parameter |
| `--wait` | Wait for all resources to be ready |
| `--timeout 5m` | Maximum wait time |

**What Happens:**
1. Helm renders templates with values
2. Compares with existing release (if any)
3. Applies changes to Kubernetes
4. Waits for pods to become ready
5. Marks release as deployed

**Expected Output:**
```
Release "my-release" does not exist. Installing it now.
NAME: my-release
LAST DEPLOYED: Sat Feb 14 18:30:00 2026
NAMESPACE: default
STATUS: deployed
REVISION: 1
```

**Deployment Process Flow:**

```
┌─────────────────────┐
│  Helm CLI Command   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Load Chart Files    │
│ - Chart.yaml        │
│ - values.yaml       │
│ - templates/        │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Render Templates    │
│ Replace {{ }} with  │
│ actual values       │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Generate Kubernetes │
│ Manifests (YAML)    │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Apply to Kubernetes │
│ via kubectl         │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Kubernetes Creates: │
│ - Deployment        │
│ - ReplicaSet        │
│ - Pods (2x)         │
│ - Service           │
│ - ServiceAccount    │
└─────────────────────┘
```

#### Stage 5: Verify Deployment

**Purpose:** Confirm that all Kubernetes resources were created successfully.

**Code:**
```groovy
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
```

**What Happens:**
1. Lists all Helm releases
2. Shows pod status
3. Displays service endpoints

**Expected Output:**
```
Helm releases:
NAME        NAMESPACE  REVISION  STATUS    CHART           APP VERSION
my-release  default    1         deployed  my-web-app-0.1.0  1.0

Pods:
NAME                                   READY   STATUS    RESTARTS   AGE
my-release-my-web-app-549c9dfd7d-abc   1/1     Running   0          30s
my-release-my-web-app-549c9dfd7d-xyz   1/1     Running   0          30s

Services:
NAME                    TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
my-release-my-web-app   NodePort   10.96.120.45   <none>        80:30080/TCP   30s
```

**Success Criteria:**
- ✅ All pods in `Running` state
- ✅ `READY` shows `1/1`
- ✅ Service has ClusterIP assigned
- ✅ NodePort is 30080

### Post-Build Actions

**Success Block:**
```groovy
post {
    success {
        echo '✅ Deployment successful!'
    }
    failure {
        echo '❌ Deployment failed!'
    }
}
```

**Possible Enhancements:**
- Send Slack/email notifications
- Update deployment status in external system
- Trigger integration tests
- Archive build artifacts

### Pipeline Execution Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    START: GitHub Push/Manual Trigger             │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
                   ┌───────────────────┐
                   │  Stage: Checkout  │
                   │  - Clone from Git │
                   └─────────┬─────────┘
                             │
                             ▼
                ┌─────────────────────────┐
                │  Stage: Setup Kubectl   │
                │  - Export KUBECONFIG    │
                │  - Verify cluster       │
                └───────────┬─────────────┘
                            │
                            ▼
               ┌──────────────────────────┐
               │  Stage: Lint Helm Chart  │
               │  - Validate syntax       │
               │  - Check structure       │
               └──────────┬───────────────┘
                          │
                          ▼
              ┌─────────────────────────────┐
              │  Stage: Deploy with Helm    │
              │  - helm upgrade --install   │
              │  - Wait for ready           │
              └──────────┬──────────────────┘
                         │
                         ▼
            ┌──────────────────────────────────┐
            │  Stage: Verify Deployment        │
            │  - Check pods running            │
            │  - Verify service created        │
            └──────────┬───────────────────────┘
                       │
           ┌───────────┴───────────┐
           │                       │
           ▼                       ▼
    ┌────────────┐         ┌────────────┐
    │  SUCCESS   │         │  FAILURE   │
    │  - Notify  │         │  - Alert   │
    │  - Archive │         │  - Log     │
    └────────────┘         └────────────┘
```

### Rollback Procedures

Helm maintains a release history, allowing easy rollbacks to previous versions.

#### View Release History

```bash
# List all revisions
helm history my-release

# Output:
# REVISION  UPDATED                   STATUS      CHART             DESCRIPTION
# 1         Sat Feb 14 10:00:00 2026  superseded  my-web-app-0.1.0  Install complete
# 2         Sat Feb 14 11:00:00 2026  deployed    my-web-app-0.1.0  Upgrade complete
```

#### Rollback to Previous Version

**Command:**
```bash
# Rollback to previous revision
helm rollback my-release

# Or rollback to specific revision
helm rollback my-release 1
```

**What Happens:**
1. Helm retrieves the previous release configuration
2. Reapplies the old manifest to Kubernetes
3. Kubernetes updates deployments to match previous state
4. Pods are recreated with old image/config

**Expected Output:**
```
Rollback was a success! Happy Helming!
```

#### Automated Rollback on Failure

**Add to Jenkinsfile:**
```groovy
post {
    failure {
        script {
            sh '''
                export KUBECONFIG=/var/lib/jenkins/.kube/config
                echo "Deployment failed! Rolling back to previous version..."
                helm rollback my-release --wait
            '''
        }
    }
}
```

#### Manual Rollback via Jenkins

Create a separate Jenkins job:

**Job Name:** `Helm-Rollback`

**Pipeline Script:**
```groovy
pipeline {
    agent any
    parameters {
        string(name: 'REVISION', defaultValue: '0', description: 'Revision number (0 = previous)')
    }
    stages {
        stage('Rollback') {
            steps {
                sh """
                    export KUBECONFIG=/var/lib/jenkins/.kube/config
                    helm rollback my-release ${params.REVISION} --wait
                """
            }
        }
        stage('Verify Rollback') {
            steps {
                sh '''
                    export KUBECONFIG=/var/lib/jenkins/.kube/config
                    helm list
                    kubectl get pods
                '''
            }
        }
    }
}
```

**Usage:**
1. Click "Build with Parameters"
2. Enter revision number (or 0 for previous)
3. Click "Build"

### Troubleshooting Pipeline Failures

#### Common Issues and Solutions

| Issue | Symptom | Solution |
|-------|---------|----------|
| **Git Clone Failure** | `ERROR: Error fetching remote repo` | Check repository URL, verify credentials |
| **Kubectl Connection** | `unable to read client-cert` | Fix certificate permissions, regenerate kubeconfig |
| **Helm Lint Errors** | `template: syntax error` | Fix YAML indentation, check template syntax |
| **Image Pull Errors** | `ImagePullBackOff` | Pre-pull image: `eval $(minikube docker-env) && docker pull nginx:alpine` |
| **Pod Not Ready** | `0/1 Running` | Check pod logs: `kubectl logs <pod-name>` |
| **Service Not Created** | Service missing | Verify service.yaml template, check labels match deployment |

#### Debug Commands

```bash
# View pipeline console output
# Jenkins UI → Job → Build # → Console Output

# Check Jenkins logs
sudo tail -f /var/log/jenkins/jenkins.log

# Verify Jenkins can access Kubernetes
sudo -u jenkins kubectl get nodes

# Check Helm release status
helm status my-release

# Describe failing pod
kubectl describe pod <pod-name>

# View pod logs
kubectl logs <pod-name>

# Check events for errors
kubectl get events --sort-by='.lastTimestamp'
```

---

## Usage Guide

### Accessing the Deployed Application

#### Method 1: NodePort (Recommended for Minikube)

```bash
# Get the Minikube IP
minikube ip
# Example output: 192.168.49.2

# Get the NodePort
kubectl get svc my-release-my-web-app
# PORT(S): 80:30080/TCP

# Access the application
curl http://192.168.49.2:30080

# Or get the URL directly
minikube service my-release-my-web-app --url
```

#### Method 2: Port Forwarding

```bash
# Forward local port 8080 to service port 80
kubectl port-forward service/my-release-my-web-app 8080:80

# Access from browser or curl
curl http://localhost:8080
```

#### Method 3: SSH Tunnel (Access from Local Machine)

On your **local MacBook**:

```bash
# Create SSH tunnel
ssh -i ~/.ssh/helm-terraform-key -L 30080:192.168.49.2:30080 ubuntu@<ec2-public-ip>

# Keep terminal open
# Access in browser: http://localhost:30080
```

### Making Changes to the Application

#### Update Replica Count

**Via values.yaml:**
```bash
# Edit values.yaml
nano my-web-app/values.yaml
# Change: replicaCount: 3

# Commit and push
git add my-web-app/values.yaml
git commit -m "Scale to 3 replicas"
git push origin main

# Jenkins will deploy automatically (if webhook configured)
# Or manually trigger "Build Now"
```

**Via Command Line:**
```bash
# One-time override
helm upgrade my-release ./my-web-app --set replicaCount=3 --wait

# Verify
kubectl get pods
```

#### Change Application Image

**Update values.yaml:**
```yaml
image:
  repository: nginx
  pullPolicy: IfNotPresent
  tag: "1.25"  # Changed from "alpine"
```

**Deploy:**
```bash
git add my-web-app/values.yaml
git commit -m "Update nginx to version 1.25"
git push origin main

# Trigger Jenkins build
```

#### Add Environment Variables

**Edit deployment.yaml template:**
```yaml
containers:
- name: {{ .Chart.Name }}
  image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
  env:
  - name: ENVIRONMENT
    value: {{ .Values.environment | default "production" | quote }}
  - name: LOG_LEVEL
    value: {{ .Values.logLevel | default "info" | quote }}
```

**Add to values.yaml:**
```yaml
environment: "staging"
logLevel: "debug"
```

### Managing the Deployment

#### View Deployment Status

```bash
# Helm release status
helm status my-release

# Detailed deployment info
kubectl describe deployment my-release-my-web-app

# Pod details
kubectl get pods -o wide

# View resource usage
kubectl top pods
```

#### Scale the Deployment

```bash
# Scale to 5 replicas
kubectl scale deployment my-release-my-web-app --replicas=5

# Verify
kubectl get pods

# Note: This is temporary. Helm upgrade will reset to values.yaml
```

#### Update the Application

```bash
# Make changes to Helm chart
# Commit to Git
git add .
git commit -m "Update application configuration"
git push origin main

# Trigger Jenkins build or run manually:
helm upgrade my-release ./my-web-app --wait
```

#### Delete the Deployment

```bash
# Uninstall Helm release (deletes all resources)
helm uninstall my-release

# Verify deletion
kubectl get all
helm list
```

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: Disk Space Full

**Symptoms:**
- Jenkins executor offline
- Error: `No space left on device`

**Solution:**
```bash
# Clean Docker
sudo docker system prune -a -f --volumes

# Clean apt cache
sudo apt clean

# Clean logs
sudo journalctl --vacuum-time=1d

# Remove old Jenkins builds
sudo rm -rf /var/lib/jenkins/workspace/*

# Check space
df -h
```

#### Issue 2: Minikube Not Starting

**Symptoms:**
- `minikube start` hangs or fails
- Docker daemon not running

**Solution:**
```bash
# Check Docker status
sudo systemctl status docker

# Restart Docker
sudo systemctl restart docker

# Delete and recreate Minikube
minikube delete
minikube start --cpus=2 --memory=4096 --driver=docker

# Verify
kubectl get nodes
```

#### Issue 3: Pods Stuck in Pending

**Symptoms:**
- `kubectl get pods` shows `Pending` status
- Pods never start

**Solution:**
```bash
# Describe pod to see reason
kubectl describe pod <pod-name>

# Common reasons:
# 1. Insufficient resources
minikube delete
minikube start --cpus=2 --memory=4096

# 2. Image pull error
eval $(minikube docker-env)
docker pull nginx:alpine

# 3. Node selector mismatch
# Remove nodeSelector from values.yaml
```

#### Issue 4: Service Not Accessible

**Symptoms:**
- Cannot access application via NodePort
- Connection refused

**Solution:**
```bash
# Verify service exists
kubectl get svc

# Check if pods are running
kubectl get pods

# Get service URL
minikube service my-release-my-web-app --url

# Test connectivity
curl $(minikube service my-release-my-web-app --url)

# Check firewall rules (AWS Security Group)
# Ensure port 30080 is open
```

#### Issue 5: Jenkins Cannot Access Kubernetes

**Symptoms:**
- Pipeline fails at "Setup Kubectl" stage
- Error: `unable to read client-cert`

**Solution:**
```bash
# Copy certificates to Jenkins
sudo mkdir -p /var/lib/jenkins/.minikube/profiles/minikube
sudo cp /home/ubuntu/.minikube/ca.crt /var/lib/jenkins/.minikube/
sudo cp /home/ubuntu/.minikube/profiles/minikube/client.crt /var/lib/jenkins/.minikube/profiles/minikube/
sudo cp /home/ubuntu/.minikube/profiles/minikube/client.key /var/lib/jenkins/.minikube/profiles/minikube/
sudo chown -R jenkins:jenkins /var/lib/jenkins/.minikube

# Regenerate kubeconfig
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
EOF

# Test
sudo -u jenkins kubectl get nodes
```

#### Issue 6: Helm Lint Failures

**Symptoms:**
- Pipeline fails at "Lint Helm Chart" stage
- Syntax errors in templates

**Common Errors and Fixes:**

**Error:** `mapping values are not allowed in this context`
```yaml
# BAD:
image:
  repository: nginx
    pullPolicy: IfNotPresent  # Extra indentation

# GOOD:
image:
  repository: nginx
  pullPolicy: IfNotPresent
```

**Error:** `template: no template "web.fullname"`
```yaml
# Ensure _helpers.tpl has the correct chart name
{{- define "my-web-app.fullname" -}}  # Not "web.fullname"
```

**Solution:**
```bash
# Lint locally before pushing
helm lint my-web-app

# Fix errors in templates
# Re-lint until clean
```

### Debugging Commands

```bash
# Check Jenkins system log
sudo journalctl -u jenkins -n 100 -f

# Check Kubernetes events
kubectl get events --sort-by='.lastTimestamp'

# Describe resources
kubectl describe deployment my-release-my-web-app
kubectl describe pod <pod-name>
kubectl describe svc my-release-my-web-app

# View logs
kubectl logs <pod-name>
kubectl logs -f <pod-name>  # Follow logs

# Check Helm release
helm get manifest my-release
helm get values my-release
helm history my-release

# Test as Jenkins user
sudo -u jenkins bash
kubectl get nodes
helm version
exit
```

---

## Project Structure

```
Configuration-Management-with-Helm/
│
├── .git/                        # Git repository metadata
├── .gitignore                   # Git ignore patterns
│
├── README.md                    # This file
│
├── Jenkinsfile                  # Jenkins pipeline definition
│
├── terraform/                   # Infrastructure as Code (optional)
│   ├── main.tf                  # Terraform configuration
│   ├── variables.tf             # Terraform variables
│   └── outputs.tf               # Terraform outputs
│
├── my-web-app/                  # Helm chart directory
│   ├── Chart.yaml               # Chart metadata
│   ├── values.yaml              # Default configuration values
│   ├── charts/                  # Dependency charts (empty)
│   └── templates/               # Kubernetes manifest templates
│       ├── NOTES.txt            # Post-installation notes
│       ├── _helpers.tpl         # Template helper functions
│       ├── deployment.yaml      # Deployment manifest
│       ├── service.yaml         # Service manifest
│       ├── serviceaccount.yaml  # ServiceAccount manifest
│       ├── hpa.yaml             # HorizontalPodAutoscaler
│       ├── ingress.yaml         # Ingress manifest
│       └── tests/
│           └── test-connection.yaml  # Helm test
│
└── docs/                        # Additional documentation
    ├── architecture.md          # Architecture diagrams
    ├── deployment-guide.md      # Deployment procedures
    └── troubleshooting.md       # Troubleshooting guide
```

---

## Future Enhancements

### Short-term Improvements

1. **GitHub Webhook Integration**
   - Automatic pipeline triggering on Git push
   - Real-time deployments

2. **Multi-Environment Support**
   - Separate `values-dev.yaml`, `values-staging.yaml`, `values-prod.yaml`
   - Environment-specific configurations

3. **Automated Testing**
   - Helm test pods
   - Integration tests after deployment
   - Smoke tests for application health

4. **Monitoring and Logging**
   - Prometheus for metrics collection
   - Grafana dashboards for visualization
   - Centralized logging with ELK stack

5. **Secrets Management**
   - Integrate HashiCorp Vault or AWS Secrets Manager
   - Encrypted secrets in Helm charts
   - External Secrets Operator

### Long-term Enhancements

1. **Production-Ready Infrastructure**
   - Multi-node Kubernetes cluster (EKS, GKE, or AKS)
   - High availability Jenkins setup
   - Load balancer for application

2. **Advanced Deployment Strategies**
   - Blue-Green deployments
   - Canary releases
   - A/B testing

3. **GitOps with ArgoCD**
   - Declarative continuous deployment
   - Automatic sync from Git
   - Rollback capabilities

4. **Security Hardening**
   - Pod Security Policies
   - Network Policies
   - RBAC fine-tuning
   - Container image scanning (Trivy, Clair)

5. **Disaster Recovery**
   - Automated backups with Velero
   - Multi-region deployment
   - Database replication

6. **Observability**
   - Distributed tracing (Jaeger, Zipkin)
   - Application Performance Monitoring (APM)
   - Custom metrics and dashboards

7. **Cost Optimization**
   - Resource right-sizing
   - Spot instances for non-production
   - Autoscaling policies

---

## Contributing

This is a capstone project for educational purposes. If you find issues or have suggestions:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

---

## License

This project is for educational purposes as part of a DevOps capstone project.

---

## Author

**Samson Boakare**  
DevOps Engineer | Healthcare Assistant transitioning to Tech  
[GitHub](https://github.com/Samjean50) | [LinkedIn](#)

---

## Acknowledgments

- **Darey.io Xternship Program** - DevOps training and mentorship
- **HNG Internship** - Practical DevOps experience (Top 29 finalist)
- **Anthropic Claude** - Technical documentation assistance
- **Kubernetes Community** - Excellent documentation and tools
- **Helm Project** - Powerful Kubernetes package manager

---

## References

- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

---

## Appendix

### Useful Kubernetes Commands

```bash
# Cluster Info
kubectl cluster-info
kubectl get nodes
kubectl get namespaces

# Resources
kubectl get all
kubectl get all -n <namespace>
kubectl get pods -o wide
kubectl get svc
kubectl get deployments

# Describe Resources
kubectl describe pod <pod-name>
kubectl describe deployment <deployment-name>
kubectl describe svc <service-name>

# Logs
kubectl logs <pod-name>
kubectl logs -f <pod-name>
kubectl logs <pod-name> -c <container-name>

# Execute Commands in Pod
kubectl exec -it <pod-name> -- /bin/bash
kubectl exec <pod-name> -- ls /app

# Port Forwarding
kubectl port-forward pod/<pod-name> 8080:80
kubectl port-forward svc/<service-name> 8080:80

# Delete Resources
kubectl delete pod <pod-name>
kubectl delete deployment <deployment-name>
kubectl delete svc <service-name>
```

### Useful Helm Commands

```bash
# Chart Management
helm create <chart-name>
helm lint <chart-path>
helm package <chart-path>
helm dependency update <chart-path>

# Release Management
helm install <release-name> <chart-path>
helm upgrade <release-name> <chart-path>
helm upgrade --install <release-name> <chart-path>
helm uninstall <release-name>

# Release Information
helm list
helm list --all-namespaces
helm status <release-name>
helm get all <release-name>
helm get values <release-name>
helm get manifest <release-name>
helm history <release-name>

# Rollback
helm rollback <release-name>
helm rollback <release-name> <revision>

# Testing
helm test <release-name>
helm template <release-name> <chart-path>
helm install <release-name> <chart-path> --dry-run --debug

# Repository Management
helm repo add <repo-name> <repo-url>
helm repo update
helm repo list
helm search repo <keyword>
```

### Git Commands Reference

```bash
# Clone Repository
git clone <repository-url>

# Check Status
git status
git log --oneline

# Stage Changes
git add <file>
git add .

# Commit Changes
git commit -m "Commit message"

# Push to Remote
git push origin <branch>

# Pull from Remote
git pull origin <branch>

# Branch Management
git branch
git checkout -b <new-branch>
git checkout <branch>
git merge <branch>

# View Differences
git diff
git diff <file>

# Undo Changes
git reset --hard HEAD
git checkout -- <file>
```

### Jenkins CLI Commands

```bash
# Download Jenkins CLI
wget http://localhost:8080/jnlpJars/jenkins-cli.jar

# List Jobs
java -jar jenkins-cli.jar -s http://localhost:8080/ list-jobs

# Build Job
java -jar jenkins-cli.jar -s http://localhost:8080/ build <job-name>

# Get Job Config
java -jar jenkins-cli.jar -s http://localhost:8080/ get-job <job-name>

# Install Plugin
java -jar jenkins-cli.jar -s http://localhost:8080/ install-plugin <plugin-name>

# Restart Jenkins
java -jar jenkins-cli.jar -s http://localhost:8080/ safe-restart
```

---

**Last Updated:** February 14, 2026  
**Version:** 1.0






# Configuration Management with Helm

A DevOps capstone project demonstrating automated deployment of a web application using Jenkins CI/CD pipeline integrated with Helm charts for Kubernetes configuration management.

## 📋 Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Technologies Used](#technologies-used)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Installation Guide](#installation-guide)
- [Usage](#usage)
- [Jenkins Pipeline](#jenkins-pipeline)
- [Helm Chart Configuration](#helm-chart-configuration)
- [Troubleshooting](#troubleshooting)
- [Project Deliverables](#project-deliverables)
- [Author](#author)

## 🎯 Project Overview

This project demonstrates the implementation of a complete CI/CD pipeline using Jenkins to automate the deployment of a web application to a Kubernetes cluster using Helm charts. The objective is to showcase practical DevOps skills including:

- Infrastructure as Code (IaC) with Terraform
- Container orchestration with Kubernetes
- Configuration management with Helm
- Continuous Integration/Continuous Deployment with Jenkins
- Cloud infrastructure provisioning on AWS

### Project Objectives

1. Design and implement a simplified CI/CD pipeline using Jenkins
2. Automate deployment of a basic web application using Helm charts
3. Demonstrate understanding of Helm chart templating and configuration
4. Integrate Jenkins with Helm for deployment automation
5. Document security measures and best practices

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS EC2 Instance                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                     Jenkins Server                       │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │              CI/CD Pipeline                        │  │   │
│  │  │  1. Checkout Code from GitHub                     │  │   │
│  │  │  2. Lint Helm Chart                               │  │   │
│  │  │  3. Deploy to Kubernetes (Minikube)               │  │   │
│  │  │  4. Verify Deployment                             │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              ↓                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Minikube (Kubernetes Cluster)               │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │        Helm Release: my-release                    │  │   │
│  │  │  ┌──────────────┐  ┌──────────────┐               │  │   │
│  │  │  │  Nginx Pod 1  │  │  Nginx Pod 2  │              │  │   │
│  │  │  └──────────────┘  └──────────────┘               │  │   │
│  │  │           ↓              ↓                          │  │   │
│  │  │  ┌────────────────────────────────┐                │  │   │
│  │  │  │   Service (NodePort 30080)     │                │  │   │
│  │  │  └────────────────────────────────┘                │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## 🛠️ Technologies Used

| Technology | Version | Purpose |
|------------|---------|---------|
| **Terraform** | 1.x | Infrastructure provisioning |
| **AWS EC2** | Ubuntu 24.04 | Cloud compute instance |
| **Jenkins** | 2.479.3 | CI/CD automation server |
| **Kubernetes** | 1.35.1 | Container orchestration |
| **Minikube** | Latest | Local Kubernetes cluster |
| **Helm** | 3.20.0 | Kubernetes package manager |
| **Docker** | Latest | Container runtime |
| **Git/GitHub** | - | Version control |
| **Nginx** | 1.21-alpine | Web application container |

## 📦 Prerequisites

### Local Machine Requirements
- Terraform >= 1.0
- AWS CLI configured with credentials
- SSH key pair (`~/.ssh/helm-terraform-key`)
- Git

### AWS Requirements
- AWS Account with appropriate permissions
- VPC with public subnet
- Security groups allowing ports: 22 (SSH), 8080 (Jenkins), 30080 (NodePort)

### Knowledge Requirements
- Basic understanding of Kubernetes concepts
- Familiarity with Helm charts
- Jenkins pipeline experience
- AWS EC2 fundamentals

## 📁 Project Structure

```
Configuration-Management-with-Helm/
├── README.md                    # Project documentation
├── Jenkinsfile                  # Jenkins pipeline definition
├── main.tf                      # Terraform infrastructure code
├── variables.tf                 # Terraform variables
├── install.sh                   # Server setup script
└── my-web-app/                  # Helm chart
    ├── Chart.yaml               # Chart metadata
    ├── values.yaml              # Default configuration values
    └── templates/               # Kubernetes manifests
        ├── _helpers.tpl         # Template helpers
        ├── deployment.yaml      # Application deployment
        ├── service.yaml         # Service definition
        ├── serviceaccount.yaml  # Service account
        ├── ingress.yaml         # Ingress configuration (optional)
        ├── hpa.yaml             # Horizontal Pod Autoscaler (optional)
        └── NOTES.txt            # Post-install instructions
```

## 🚀 Installation Guide

### Step 1: Clone the Repository

```bash
git clone https://github.com/Samjean50/Configuration-Management-with-Helm.git
cd Configuration-Management-with-Helm
```

### Step 2: Generate SSH Key Pair

```bash
# Generate SSH key for Terraform
ssh-keygen -t rsa -b 4096 -f ~/.ssh/helm-terraform-key -N ""
```

### Step 3: Provision Infrastructure with Terraform

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply infrastructure
terraform apply -auto-approve

# Note the output - you'll need the public IP
```

**Terraform will provision:**
- VPC with public subnet
- Internet Gateway
- Route tables
- Security groups
- EC2 instance (t3.medium)
- Automated installation of: Jenkins, Docker, Kubectl, Helm, Minikube

### Step 4: Access Jenkins

```bash
# Get the EC2 public IP from Terraform output
terraform output instance_public_ip

# Access Jenkins
# URL: http://<public-ip>:8080

# Get initial admin password
ssh -i ~/.ssh/helm-terraform-key ubuntu@<public-ip> 'cat jenkins-initial-password.txt'
```

### Step 5: Configure Jenkins

1. **Initial Setup**
   - Enter the admin password
   - Install suggested plugins
   - Create admin user

2. **Configure Executors**
   - Go to **Manage Jenkins** → **System**
   - Set **# of executors** to `5`
   - Click **Save**

3. **Install Required Plugins** (if not already installed)
   - Git plugin
   - Pipeline plugin
   - GitHub plugin

### Step 6: Create Jenkins Pipeline Job

1. Click **"New Item"**
2. Enter name: `Helm-integration`
3. Select **"Pipeline"**
4. Click **OK**
5. Under **Pipeline**:
   - **Definition**: `Pipeline script from SCM`
   - **SCM**: `Git`
   - **Repository URL**: `https://github.com/Samjean50/Configuration-Management-with-Helm.git`
   - **Branch**: `*/main`
   - **Script Path**: `Jenkinsfile`
6. Click **Save**

### Step 7: Configure Kubernetes Access for Jenkins

SSH into the EC2 instance and run:

```bash
# Copy Minikube certificates to Jenkins
sudo mkdir -p /var/lib/jenkins/.minikube/profiles/minikube
sudo cp /home/ubuntu/.minikube/ca.crt /var/lib/jenkins/.minikube/
sudo cp /home/ubuntu/.minikube/profiles/minikube/client.crt /var/lib/jenkins/.minikube/profiles/minikube/
sudo cp /home/ubuntu/.minikube/profiles/minikube/client.key /var/lib/jenkins/.minikube/profiles/minikube/
sudo chown -R jenkins:jenkins /var/lib/jenkins/.minikube

# Create Jenkins kubeconfig
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

## 💻 Usage

### Deploy via Jenkins Pipeline

1. Go to Jenkins Dashboard
2. Click on **"Helm-integration"** job
3. Click **"Build Now"**
4. Monitor the **Console Output**

The pipeline will:
- Checkout code from GitHub
- Configure kubectl context
- Lint the Helm chart
- Deploy the application to Kubernetes
- Verify the deployment

### Manual Deployment (Alternative)

```bash
# SSH into EC2 instance
ssh -i ~/.ssh/helm-terraform-key ubuntu@<public-ip>

# Navigate to the project
cd Configuration-Management-with-Helm

# Lint the Helm chart
helm lint my-web-app

# Install/Upgrade the release
helm upgrade --install my-release ./my-web-app \
  --namespace default \
  --set replicaCount=2

# Verify deployment
kubectl get pods
kubectl get svc
helm list
```

### Access the Application

**Method 1: Port Forwarding**
```bash
kubectl port-forward service/my-release-my-web-app 8080:80
# Access at http://localhost:8080
```

**Method 2: NodePort (from EC2)**
```bash
# Get the URL
minikube service my-release-my-web-app --url

# Access via curl
curl $(minikube service my-release-my-web-app --url)
```

**Method 3: SSH Tunnel (from local machine)**
```bash
# On your local machine
ssh -i ~/.ssh/helm-terraform-key -L 30080:192.168.49.2:30080 ubuntu@<ec2-ip>

# Open browser: http://localhost:30080
```

## 🔄 Jenkins Pipeline

### Pipeline Stages

```groovy
pipeline {
    agent any
    
    stages {
        stage('Checkout') {
            // Clone repository from GitHub
        }
        
        stage('Setup Kubectl') {
            // Configure kubectl to use Minikube
        }
        
        stage('Lint Helm Chart') {
            // Validate Helm chart syntax
        }
        
        stage('Deploy with Helm') {
            // Deploy application to Kubernetes
        }
        
        stage('Verify Deployment') {
            // Check pods, services, and Helm releases
        }
    }
}
```

### Pipeline Features

- ✅ Automated code checkout from GitHub
- ✅ Kubernetes cluster configuration
- ✅ Helm chart validation
- ✅ Automated deployment with rollback capability
- ✅ Post-deployment verification
- ✅ Build status notifications

## ⚙️ Helm Chart Configuration

### Chart.yaml

```yaml
apiVersion: v2
name: my-web-app
description: A simple web application
type: application
version: 0.1.0
appVersion: "1.0"
```

### Key Configuration Options (values.yaml)

```yaml
# Number of pod replicas
replicaCount: 2

# Container image configuration
image:
  repository: nginx
  pullPolicy: IfNotPresent
  tag: "alpine"

# Service configuration
service:
  type: NodePort      # ClusterIP, NodePort, LoadBalancer
  port: 80
  nodePort: 30080

# Resource limits
resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi

# Autoscaling (optional)
autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
```

### Customizing Deployment

**Change replica count:**
```bash
helm upgrade my-release ./my-web-app --set replicaCount=3
```

**Use different image:**
```bash
helm upgrade my-release ./my-web-app --set image.repository=httpd --set image.tag=alpine
```

**Enable autoscaling:**
```bash
helm upgrade my-release ./my-web-app --set autoscaling.enabled=true
```

## 🔧 Troubleshooting

### Jenkins Executor Offline

**Problem:** Build stuck with "Waiting for executor"  
**Solution:**
```bash
# Check disk space
df -h

# Clean up if needed
sudo docker system prune -a -f --volumes
sudo apt clean

# Restart Jenkins
sudo systemctl restart jenkins
```

### Kubectl Permission Denied

**Problem:** Jenkins can't access Kubernetes  
**Solution:**
```bash
# Fix certificate permissions
sudo chmod -R +r /home/ubuntu/.minikube/
sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube
```

### Pods in ImagePullBackOff

**Problem:** Pods can't pull container image  
**Solution:**
```bash
# Configure to use Minikube's Docker
eval $(minikube docker-env)

# Pull image into Minikube
docker pull nginx:alpine

# Reinstall
helm uninstall my-release
helm install my-release ./my-web-app
```

### Minikube InsufficientStorage

**Problem:** Minikube host shows InsufficientStorage  
**Solution:**
```bash
# Clean Minikube cache
minikube ssh -- docker system prune -a -f

# Or recreate with more disk space
minikube delete
minikube start --disk-size=20g --cpus=2 --memory=4096
```

### Common Commands

```bash
# View pod logs
kubectl logs <pod-name>

# Describe pod for details
kubectl describe pod <pod-name>

# Check Helm release history
helm history my-release

# Rollback to previous version
helm rollback my-release

# Delete release
helm uninstall my-release

# Restart Jenkins
sudo systemctl restart jenkins

# Restart Minikube
minikube stop
minikube start
```

## 📝 Project Deliverables

### Documentation

- [x] README.md with comprehensive project overview
- [x] Step-by-step installation guide
- [x] Architecture diagram
- [x] Troubleshooting guide

### Helm Chart Components

- [x] Chart.yaml - Chart metadata
- [x] values.yaml - Configuration values
- [x] deployment.yaml - Application deployment
- [x] service.yaml - Service definition
- [x] serviceaccount.yaml - Service account
- [x] _helpers.tpl - Template helpers
- [x] NOTES.txt - Post-install instructions

### CI/CD Implementation

- [x] Jenkinsfile - Pipeline definition
- [x] GitHub integration
- [x] Automated deployment workflow
- [x] Post-deployment verification

### Infrastructure as Code

- [x] Terraform configuration (main.tf)
- [x] Automated server provisioning
- [x] Security group configuration
- [x] Installation automation script

### Security Measures

- [x] SSH key-based authentication
- [x] Security groups with minimal required ports
- [x] Jenkins authentication
- [x] Kubernetes RBAC via service accounts
- [x] Non-root container execution

## 🎓 Learning Outcomes

This project demonstrates proficiency in:

1. **Container Orchestration**: Deploying and managing containerized applications with Kubernetes
2. **Configuration Management**: Using Helm charts for templating and version control
3. **CI/CD Automation**: Building automated pipelines with Jenkins
4. **Infrastructure as Code**: Provisioning cloud resources with Terraform
5. **Cloud Computing**: Working with AWS EC2 and related services
6. **DevOps Best Practices**: Version control, documentation, and security


## 🔐 Security Considerations

1. **SSH Access**: Key-based authentication only, no password access
2. **Jenkins**: Configured with user authentication and authorization
3. **Kubernetes**: Service accounts with minimal required permissions
4. **Network**: Security groups restrict access to specific ports
5. **Container Images**: Using official, minimal Alpine-based images
6. **Secrets Management**: Kubernetes secrets for sensitive data (future enhancement)


## Project Steps

![steps](images/1.png)
![steps](images/2.png)
![steps](images/3.png)
![steps](images/4.png)
![steps](images/5.png)
![steps](images/6.png)
![steps](images/7.png)
![steps](images/8.png)
![steps](images/9.png)
![steps](images/10.0.png)
![steps](images/10.png)
![steps](images/11.png)
![steps](images/12.png)
![steps](images/20.png)
![steps](images/21.png)
![steps](images/22.png)
![steps](images/23.png)
![steps](images/24.png)
![steps](images/25.png)
![steps](images/26.png)
![steps](images/27.png)
![steps](images/30.png)
![steps](images/31.png)
![steps](images/32.png)
![steps](images/33.png)
![steps](images/34.png)
![steps](images/35.png)
![steps](images/36.png)
![steps](images/37.png)
![steps](images/webhook.png)
![steps](images/38.png)
![steps](images/39.png)
![steps](images/40.png)
![steps](images/41.png)
![steps](images/42.png)
![steps](images/43.png)