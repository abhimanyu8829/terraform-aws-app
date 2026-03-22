# ============================================================
#  terraform.tfvars.example
#  cp terraform.tfvars.example terraform.tfvars  then fill in.
# ============================================================

region      = "us-east-1"
project     = "myapp"
environment = "prod"

vpc_cidr    = "10.0.0.0/16"
subnet_cidr = "10.0.1.0/24"

instance_type       = "t2.micro"
root_volume_size_gb = 20
ssh_public_key_path = "~/.ssh/id_rsa.pub"
ssh_allowed_cidr    = "0.0.0.0/0"   # change to "YOUR.IP/32" in prod

app_docker_user     = "appuser"
app_docker_password = "Nitroberry@2026!"

app_port = 3000

# Services to create ECR repos for (matches matrix.service in CI/CD)
ecr_repositories = ["api", "cron", "dev", "prod"]
