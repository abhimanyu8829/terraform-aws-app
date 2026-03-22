# ============================================================
#  variables.tf
# ============================================================

variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "project" {
  type    = string
  default = "myapp"
}

variable "environment" {
  type    = string
  default = "prod"
}

# ── Networking ───────────────────────────────────────────────
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

# ── VM ───────────────────────────────────────────────────────
variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "root_volume_size_gb" {
  type    = number
  default = 20
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}

variable "ssh_allowed_cidr" {
  description = "Your IP for SSH. Change to YOUR.IP/32 in production."
  type        = string
  default     = "0.0.0.0/0"
}

# ── App user (runs Docker on the EC2) ────────────────────────
variable "app_docker_user" {
  type    = string
  default = "appuser"
}

variable "app_docker_password" {
  type      = string
  sensitive = true
}

# ── App ──────────────────────────────────────────────────────
variable "app_port" {
  type    = number
  default = 3000
}

# ── ECR repos to create ──────────────────────────────────────
#   These match the matrix.service values in your CI workflow
variable "ecr_repositories" {
  type    = list(string)
  default = ["api", "cron", "dev", "prod"]
}
