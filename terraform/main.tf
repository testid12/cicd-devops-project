module "vpc" {
  source = "./modules/vpc"

  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  availability_zone   = var.availability_zone
}

module "ec2" {
  source = "./modules/ec2"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  subnet_id         = module.vpc.public_subnet_id
  instance_type     = var.instance_type
  key_pair_name     = var.key_pair_name
  ssh_allowed_cidr  = var.ssh_allowed_cidr
  app_port          = var.app_port
  docker_image      = var.docker_image
}
