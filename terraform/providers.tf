terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Optional: uncomment and configure a remote backend for team use.
  # backend "s3" {
  #   bucket         = "YOUR_TF_STATE_BUCKET"
  #   key            = "cicd-devops-project/terraform.tfstate"
  #   region         = "ap-south-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

# AWS credentials are picked up automatically from:
#   - Environment variables (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY)
#   - Jenkins AWS Credentials Binding plugin
#   - AWS CLI profile (~/.aws/credentials) for local runs
# Never hardcode credentials here.
provider "aws" {
  region = var.aws_region
}
