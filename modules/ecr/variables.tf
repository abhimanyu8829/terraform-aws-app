variable "name_prefix" {
  type = string
}

variable "ecr_repositories" {
  type = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}