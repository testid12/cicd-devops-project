output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = module.vpc.public_subnet_id
}

output "ec2_instance_id" {
  description = "ID of the EC2 instance running the application"
  value       = module.ec2.instance_id
}

output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = module.ec2.public_ip
}

output "application_url" {
  description = "URL where the deployed application is reachable"
  value       = "http://${module.ec2.public_ip}:${var.app_port}"
}
