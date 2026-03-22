# ============================================================
#  modules/ecr/main.tf
#  Creates one ECR repository per service (api, cron, dev, prod)
#  with image scan on push + lifecycle policy to keep costs low.
# ============================================================

resource "aws_ecr_repository" "repos" {
  for_each             = toset(var.ecr_repositories)
  name                 = "${var.name_prefix}-${each.key}"
  image_tag_mutability = "MUTABLE"

  force_delete = true  

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, { Service = each.key })
}

# ── Lifecycle policy: keep only last 10 tagged images per repo ─
resource "aws_ecr_lifecycle_policy" "repos" {
  for_each   = aws_ecr_repository.repos
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 versioned images (0.0.0.X)"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["0.0.0."]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Remove untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      }
    ]
  })
}

# ── IAM policy: allow EC2 instance to pull from ECR ──────────
#   Attached to the EC2 instance role so docker pull works
#   without storing AWS keys on the server.
resource "aws_iam_role" "ec2_ecr_pull" {
  name = "${var.name_prefix}-ec2-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "ecr_pull" {
  name = "${var.name_prefix}-ecr-pull-policy"
  role = aws_iam_role.ec2_ecr_pull.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRPull"
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_ecr" {
  name = "${var.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2_ecr_pull.name
  tags = var.tags
}
