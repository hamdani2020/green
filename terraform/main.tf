terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Networking Module
module "networking" {
  source = "./modules/networking"
  
  app_name           = var.app_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = data.aws_availability_zones.available.names
}

# Security Module
module "security" {
  source = "./modules/security"
  
  app_name    = var.app_name
  environment = var.environment
  vpc_id      = module.networking.vpc_id
}

# Load Balancer Module
module "load_balancer" {
  source = "./modules/load_balancer"
  
  app_name           = var.app_name
  environment        = var.environment
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  alb_security_group = module.security.alb_security_group_id
}

# ECR Module
module "ecr" {
  source = "./modules/ecr"
  
  app_name    = var.app_name
  environment = var.environment
}

# ECS Module
module "ecs" {
  source = "./modules/ecs"
  
  app_name              = var.app_name
  environment           = var.environment
  aws_region            = var.aws_region
  gemini_api_key        = var.gemini_api_key
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  ecs_security_group_id = module.security.ecs_security_group_id
  target_group_arn      = module.load_balancer.target_group_arn
  ecr_repository_url    = module.ecr.repository_url
  desired_count         = var.desired_count
  cpu                   = var.cpu
  memory                = var.memory
}