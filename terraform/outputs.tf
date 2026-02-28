# Output the public IP and Jenkins password location
output "instance_public_ip" {
  value       = aws_instance.server.public_ip
  description = "Public IP of the Jenkins server"
}

output "jenkins_url" {
  value       = "http://${aws_instance.server.public_ip}:8080"
  description = "Jenkins web interface URL"
}

output "ssh_command" {
  value       = "ssh -i ~/.ssh/helm-terraform-key ubuntu@${aws_instance.server.public_ip}"
  description = "SSH command to connect to the server"
}

output "jenkins_password_command" {
  value       = "ssh -i ~/.ssh/helm-terraform-key ubuntu@${aws_instance.server.public_ip} 'cat jenkins-initial-password.txt'"
  description = "Command to retrieve Jenkins initial password"
}