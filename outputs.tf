# ============================================================
#  outputs.tf
#  After `terraform apply`, copy these values into
#  your GitHub repository secrets.
# ============================================================

output "public_ip" {
  description = "EC2 public IP → GitHub Secret: EC2_HOST"
  value       = module.vm.public_ip
}

output "ssh_command" {
  description = "Ready-to-run SSH command for manual access"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${module.vm.public_ip}"
}

output "app_url" {
  description = "Application URL (via Nginx)"
  value       = "http://${module.vm.public_ip}"
}

output "ecr_endpoint" {
  description = "ECR registry endpoint → GitHub Secret: CR_ENDPOINT"
  value       = module.ecr.ecr_endpoint
}

output "ecr_repository_urls" {
  description = "Full ECR repository URLs per service"
  value       = module.ecr.repository_urls
}

output "github_secrets_to_set" {
  description = "Paste these values into GitHub → Settings → Secrets"
  value = {
    AWS_REGION             = var.region
    CR_ENDPOINT            = module.ecr.ecr_endpoint
    CR_REPOSITORY_API      = "${local.name_prefix}-api"
    CR_REPOSITORY_CRON     = "${local.name_prefix}-cron"
    CR_REPOSITORY_DEV      = "${local.name_prefix}-dev"
    CR_REPOSITORY_PROD     = "${local.name_prefix}-prod"
    EC2_HOST               = module.vm.public_ip
    EC2_USER               = "ubuntu"
    APP_DOCKER_USER        = var.app_docker_user
  }
  sensitive = false
}

locals {
}
