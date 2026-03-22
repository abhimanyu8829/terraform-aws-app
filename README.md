# AWS Terraform + CI/CD Pipeline

## Full architecture

```
Developer pushes to main
         │
         ▼
  GitHub Actions CI/CD
  ┌─────────────────────────────────────────────┐
  │  Job 1: Lint & Test (once)                  │
  │         ↓                                   │
  │  Job 2: Build + Scan + Push (×4 parallel)   │
  │    api  │  cron  │  dev  │  prod            │
  │    ↓    ↓    ↓    ↓                         │
  │         ECR (4 repos)                        │
  │         ↓                                   │
  │  Job 3: Deploy to EC2 via SSH               │
  │    → docker pull (ECR via IAM role)          │
  │    → docker stop old → docker run new        │
  │    → /health check                           │
  └─────────────────────────────────────────────┘
         │
         ▼
    EC2 (Ubuntu)
    ├── Nginx (port 80 → localhost:3000)
    ├── Docker container (your app)
    └── IAM role (pulls ECR without keys)
```

---

## Folder structure

```
terraform-aws-app/
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars.example
├── .github/
│   └── workflows/
│       └── ci-cd.yml          ← complete CI/CD pipeline
├── scripts/
│   └── cloud-init.sh.tpl      ← first-boot setup on EC2
└── modules/
    ├── ecr/
    │   ├── main.tf            ← ECR repos + IAM role for EC2 pull
    │   ├── variables.tf
    │   └── outputs.tf
    └── vm/
        ├── network.tf         ← VPC, subnet, IGW, SG, EIP
        ├── instance.tf        ← EC2 + key pair
        ├── variables.tf
        └── outputs.tf
```

---

## Step 1 — Provision infrastructure with Terraform

```bash
# 1. Copy and fill in variables
cp terraform.tfvars.example terraform.tfvars
# Edit: app_docker_password, ssh_allowed_cidr

# 2. Create SSH key if you don't have one
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa

# 3. Init + apply
terraform init
terraform plan
terraform apply
```

After apply you'll see output like:
```
public_ip    = "13.x.x.x"
ecr_endpoint = "123456789.dkr.ecr.ap-south-1.amazonaws.com"
github_secrets_to_set = {
  AWS_REGION         = "ap-south-1"
  CR_ENDPOINT        = "123456789.dkr.ecr.ap-south-1.amazonaws.com"
  CR_REPOSITORY_API  = "myapp-prod-api"
  ...
}
```

---

## Step 2 — Set GitHub Secrets

Go to your repo → **Settings → Secrets and variables → Actions → New repository secret**

| Secret name | Where to get the value |
|---|---|
| `AWS_ACCESS_KEY_ID` | AWS IAM → create access key for CI user |
| `AWS_SECRET_ACCESS_KEY` | same |
| `AWS_REGION` | from terraform output |
| `CR_ENDPOINT` | from terraform output |
| `CR_REPOSITORY_API` | from terraform output |
| `CR_REPOSITORY_CRON` | from terraform output |
| `CR_REPOSITORY_DEV` | from terraform output |
| `CR_REPOSITORY_PROD` | from terraform output |
| `EC2_HOST` | `terraform output public_ip` |
| `EC2_USER` | `ubuntu` |
| `EC2_SSH_PRIVATE_KEY` | contents of `~/.ssh/id_rsa` (the private key) |
| `APP_PORT` | `3000` (or whatever your app uses) |
| `APP_DOCKER_USER` | `appuser` |

---

## Step 3 — Push to main

```bash
git add .
git commit -m "initial deploy"
git push origin main
```

The pipeline runs:
1. **Lint & Test** — prettier + npm test
2. **Build & Push** — 4 services in parallel, auto-tag 0.0.0.X
3. **Deploy** — SSH into EC2, pull new api image, restart container, health check

---

## How the EC2 pulls from ECR without storing AWS keys

The EC2 instance has an **IAM Instance Profile** attached (created by Terraform). When the deploy script runs `docker pull`, Docker uses `amazon-ecr-credential-helper` which calls the instance metadata endpoint to get temporary credentials automatically. No AWS keys ever touch the server.

---

## Useful commands

```bash
# SSH into server
ssh -i ~/.ssh/id_rsa ubuntu@$(terraform output -raw public_ip)

# Watch deploy logs
tail -f /var/log/deploy.log

# Watch cloud-init logs (first boot)
tail -f /var/log/cloud-init-app.log

# Check running containers
docker ps

# Restart the app manually
IMAGE=<ecr_url>/<repo> TAG=0.0.0.5 SERVICE=api APP_PORT=3000 APP_USER=appuser \
  bash /usr/local/bin/deploy.sh

# Destroy everything
terraform destroy
```

---

## Creating the AWS IAM user for GitHub Actions

Create a dedicated CI user in AWS with the minimum permissions needed:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeImages",
        "ecr:ListImages"
      ],
      "Resource": "*"
    }
  ]
}
```

Attach this policy to an IAM user → generate an access key → put in GitHub secrets.
# terraform-aws-app
