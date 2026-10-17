variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "cluster_name" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "azs" {
  type = list(string)
}

variable "owner" {
  type    = string
  default = "platform-team"
}
