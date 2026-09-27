variable "project_name" {
  description = "Prefix used for naming resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment tag"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID the instance and security group belong to"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID to launch the EC2 instance into"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "key_pair_name" {
  description = "Existing AWS EC2 key pair name used for SSH access"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR range allowed to SSH into the instance"
  type        = string
}

variable "app_port" {
  description = "Port the application container listens on"
  type        = number
}

variable "docker_image" {
  description = "Docker image (name:tag) to run on first boot"
  type        = string
  default     = ""
}
