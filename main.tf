terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
      Purpose   = "cs6747"
    }
  }
}

# get aws account and network information
module "aws_data" {
  source = "./modules/aws-data"
}

# create security groups
module "security" {
  source = "./modules/security"

  project_name         = var.project_name
  vpc_id               = module.aws_data.vpc_id
  ghidra_allowed_cidrs = concat(var.allowed_ghidra_cidrs)
}

# deploy Ghidra server
module "ghidra_server" {
  source = "./modules/ghidra-server"

  project_name      = var.project_name
  ami_id            = module.aws_data.ubuntu_ami_id
  instance_type     = var.instance_type
  subnet_id         = tolist(module.aws_data.subnet_ids)[0]
  security_group_id = module.security.ghidra_server_sg_id
  ghidra_users      = var.ghidra_users
}

# billing alarm to avoid expensive cloud hosting
module "budget" {
  source                   = "./modules/budget"
  project_name             = var.project_name
  monthly_budget_limit_usd = var.monthly_budget_limit_usd
  billing_emails           = var.billing_emails
  enable_budget            = var.enable_budget
}