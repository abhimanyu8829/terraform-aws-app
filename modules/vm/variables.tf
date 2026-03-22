variable "name_prefix" {
  type = string
}

variable "region" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "root_volume_size_gb" {
  type = number
}

variable "ssh_public_key_path" {
  type = string
}

variable "ssh_allowed_cidr" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "subnet_cidr" {
  type = string
}

variable "app_port" {
  type = number
}

variable "app_docker_user" {
  type = string
}

variable "app_docker_password" {
  type      = string
  sensitive = true
}

variable "ecr_endpoint" {
  type = string
}

variable "ecr_instance_profile_name" {
  type    = string
  default = ""
}

variable "account_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}