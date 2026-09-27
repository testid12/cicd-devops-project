variable "aws_region" {
  description = "AWS region to deploy infrastructure into"
  type        = string
  default     = "ap-south-1" # USER MAY CHANGE: e.g. us-east-1, eu-west-1
}

variable "project_name" {
  description = "Name used as a prefix for all created resources"
  type        = string
  default     = "cicd-devops-project"
}

variable "environment" {
  description = "Deployment environment tag"
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Availability zone for the public subnet"
  type        = string
  default     = "ap-south-1a" # USER MUST MATCH THIS TO aws_region
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro" # Free-tier eligible
}

variable "key_pair_name" {
  description = "Name of an existing EC2 Key Pair in AWS (USER MUST PROVIDE)"
  type        = string
  # No default on purpose: the user must create/import a key pair in
  # the AWS console or CLI and set this in terraform.tfvars
}

variable "ssh_allowed_cidr" {
  description = "CIDR range allowed to SSH into the EC2 instance. Restrict this to your own IP, e.g. 1.2.3.4/32"
  type        = string
  default     = "0.0.0.0/0" # USER SHOULD RESTRICT THIS FOR SECURITY
}

variable "app_port" {
  description = "Port the containerized application listens on"
  type        = number
  default     = 5000
}

variable "docker_image" {
  description = "Full Docker image reference (name:tag) to deploy, e.g. yourdockerhubuser/cicd-demo-app:latest"
  type        = string
  default     = "" # Passed in by Jenkins via -var, or set manually
}
