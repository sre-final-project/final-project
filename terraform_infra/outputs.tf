output "instance_public_ip" {
  description = "Public IP address of EC2 instance"
  value       = aws_instance.ecommerce.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of EC2 instance"
  value       = aws_instance.ecommerce.private_ip
}

output "instance_id" {
  description = "ID of EC2 instance"
  value       = aws_instance.ecommerce.id
}

output "security_group_id" {
  description = "ID of security group"
  value       = aws_security_group.ecommerce.id
}

output "vpc_id" {
  description = "ID of VPC"
  value       = aws_vpc.main.id
}

output "ssh_command" {
  description = "SSH command to connect to instance"
  value       = "ssh -i ecommerce-deployer.pem ubuntu@${aws_instance.ecommerce.public_ip}"
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "http://${aws_instance.ecommerce.public_ip}:3000"
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://${aws_instance.ecommerce.public_ip}:9090"
}

output "application_url" {
  description = "Application URL"
  value       = "http://${aws_instance.ecommerce.public_ip}:4000"
}