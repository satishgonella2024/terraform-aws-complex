terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "terraform-complex-state-2024-demo"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-complex-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = terraform.workspace
      ManagedBy   = "terraform"
      Project     = var.project_name
    }
  }
}

locals {
  environment = terraform.workspace
  azs         = ["${var.aws_region}a", "${var.aws_region}b"]

  asg_tags = {
    Name        = "${var.project_name}-${local.environment}-instance"
    Environment = local.environment
    Project     = var.project_name
  }
}

module "networking" {
  source = "./modules/networking"

  project_name = var.project_name
  environment  = local.environment
  aws_region   = var.aws_region
  vpc_cidr     = var.vpc_cidr
  azs          = local.azs
}

module "security" {
  source = "./modules/security"

  project_name = var.project_name
  environment  = local.environment
  vpc_id       = module.networking.vpc_id
}

module "compute" {
  source = "./modules/compute"

  project_name          = var.project_name
  environment           = local.environment
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id = module.security.alb_security_group_id
  web_security_group_id = module.security.web_security_group_id

  instance_type            = var.instance_type
  asg_desired_capacity     = var.asg_desired_capacity
  asg_max_size             = var.asg_max_size
  asg_min_size             = var.asg_min_size
  scale_up_cpu_threshold   = var.scale_up_cpu_threshold
  scale_down_cpu_threshold = var.scale_down_cpu_threshold

  asg_tags = local.asg_tags
}