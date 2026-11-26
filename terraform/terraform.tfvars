aws_region        = "ap-south-1"
availability_zone = "ap-south-1a"
project_name      = "cicd-devops-project"
environment       = "production"

vpc_cidr          = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"

instance_type     = "t2.micro"
key_pair_name     = "cicd-key"

ssh_allowed_cidr  = "YOUR_IP_ADDRESS/32"
app_port          = 5000

docker_image      = "princeydv77/cicd-demo-app:latest"
