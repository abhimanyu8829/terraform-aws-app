# ============================================================
#  modules/vm/instance.tf
#  EC2 instance with:
#    - IAM instance profile → can pull from ECR without keys
#    - cloud-init script    → installs Docker, Nginx, app user
# ============================================================

resource "aws_key_pair" "main" {
  key_name   = "${var.name_prefix}-key"
  public_key = file(var.ssh_public_key_path)
  tags       = var.tags
}

resource "aws_instance" "main" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.vm.id]
  key_name               = aws_key_pair.main.key_name

  # IAM role allows the EC2 to run `aws ecr get-login-password`
  # and `docker pull` from ECR — no AWS keys stored on server!
  iam_instance_profile = var.ecr_instance_profile_name

user_data = base64encode(templatefile(
  "${path.module}/../../scripts/cloud-init.sh.tpl",
  {
    app_docker_user     = var.app_docker_user
    app_docker_password = var.app_docker_password
    app_port            = var.app_port
    ecr_endpoint        = var.ecr_endpoint

    aws_region          = var.region   # ✅ FIX
    image               = var.ecr_endpoint
    tag                 = "latest"
  }
))
  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size_gb
    delete_on_termination = true
    encrypted             = true
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-vm" })
}
