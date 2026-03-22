# ============================================================
#  main.tf
# ============================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Recommended: store state remotely
  # backend "s3" {
  #   bucket = "my-tfstate-bucket"
  #   key    = "myapp/prod/terraform.tfstate"
  #   region = "ap-south-1"
  # }
}

provider "aws" {
  region = var.region
}

# ── Latest Ubuntu 22.04 LTS ──────────────────────────────────
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── Current AWS account ID (used in ECR ARN policies) ────────
data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project}-${var.environment}"
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ── ECR Module ───────────────────────────────────────────────
module "ecr" {
  source           = "./modules/ecr"
  name_prefix      = local.name_prefix
  ecr_repositories = var.ecr_repositories
  tags             = local.common_tags
}

# ── VM Module ────────────────────────────────────────────────
module "vm" {
  source = "./modules/vm"

  name_prefix         = local.name_prefix
  region              = var.region
  ami_id              = data.aws_ami.ubuntu.id
  instance_type       = var.instance_type
  root_volume_size_gb = var.root_volume_size_gb
  ssh_public_key_path = var.ssh_public_key_path
  ssh_allowed_cidr    = var.ssh_allowed_cidr
  vpc_cidr            = var.vpc_cidr
  subnet_cidr         = var.subnet_cidr
  app_port            = var.app_port
  app_docker_user     = var.app_docker_user
  app_docker_password = var.app_docker_password
  ecr_endpoint              = module.ecr.ecr_endpoint
  ecr_instance_profile_name = module.ecr.instance_profile_name
  account_id                = data.aws_caller_identity.current.account_id
  tags                = local.common_tags
}
