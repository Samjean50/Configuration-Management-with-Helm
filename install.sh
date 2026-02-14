#!/bin/bash
set -x  # Print each command
set -e  # Exit on error

echo "=== Starting Installation ==="

# Wait for any background apt processes to complete
echo "Waiting for apt locks..."
while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
  sleep 1
done

# Update system
echo "=== Updating System ==="
sudo apt-get update -y
sudo apt-get upgrade -y



#
echo "=== Installing Java ==="
sudo apt-get update -y
sudo apt-get install -y fontconfig openjdk-17-jre
java -version

echo "=== Installing Jenkins from Package ==="
cd /tmp
wget https://pkg.jenkins.io/debian-stable/binary/jenkins_2.479.3_all.deb
sudo dpkg -i jenkins_2.479.3_all.deb || sudo apt-get install -f -y
sudo systemctl daemon-reload
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Wait for Jenkins to start
echo "Waiting for Jenkins to start..."
sleep 30

# Check status
sudo systemctl status jenkins --no-pager

# Install Docker
echo "=== Installing Docker ==="
sudo apt-get install -y docker.io
sudo usermod -aG docker ubuntu
sudo usermod -aG docker jenkins
sudo systemctl enable docker
sudo systemctl start docker

# Verify Docker
sudo docker --version

# Install kubectl
echo "=== Installing kubectl ==="
cd /tmp
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Verify kubectl
kubectl version --client

# Install Helm
echo "=== Installing Helm ==="
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify Helm
helm version

# Install Minikube
echo "=== Installing Minikube ==="
cd /tmp
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64

# Verify Minikube
minikube version

# Create Helm chart as ubuntu user
echo "=== Creating Helm Chart ==="
cd /home/ubuntu
sudo -u ubuntu helm create my-web-app

# Wait for Jenkins to fully start and save password
echo "=== Waiting for Jenkins to initialize ==="
sleep 60

if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
  sudo cat /var/lib/jenkins/secrets/initialAdminPassword > /home/ubuntu/jenkins-initial-password.txt
  sudo chown ubuntu:ubuntu /home/ubuntu/jenkins-initial-password.txt
  echo "Jenkins password saved to jenkins-initial-password.txt"
else
  echo "WARNING: Jenkins password file not found yet"
fi

# Mark setup complete
echo "Setup complete at $(date)" | tee /home/ubuntu/setup-complete.txt

echo "=== Installation Complete ==="


echo "=== Verification ==="
echo "Java: $(java -version 2>&1 | head -n1)"
echo "Jenkins: $(jenkins --version 2>&1)"
echo "Docker: $(docker --version)"
echo "kubectl: $(kubectl version --client --short 2>&1)"
echo "Helm: $(helm version --short)"
echo "Minikube: $(minikube version --short)"

echo ""
echo "=== Setup Complete! ==="
echo "Jenkins Password: $(cat /home/ubuntu/jenkins-initial-password.txt)"
echo "Access Jenkins at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"