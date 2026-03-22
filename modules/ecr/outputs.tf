# modules/ecr/outputs.tf

output "ecr_endpoint" {
  # e.g. 123456789.dkr.ecr.ap-south-1.amazonaws.com
  value = split("/", aws_ecr_repository.repos[keys(aws_ecr_repository.repos)[0]].repository_url)[0]
}

output "repository_urls" {
  value = { for k, v in aws_ecr_repository.repos : k => v.repository_url }
}

output "instance_profile_name" {
  value = aws_iam_instance_profile.ec2_ecr.name
}
