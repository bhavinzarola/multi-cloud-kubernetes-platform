variable "cluster_name" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "karpenter_version" {
  type    = string
  default = "0.37.0"
}

variable "karpenter_role_arn" {
  description = "IRSA role ARN for the Karpenter controller (from the eks module)"
  type        = string
}

variable "node_instance_profile_name" {
  description = "Instance profile name Karpenter-provisioned nodes will use"
  type        = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "cluster_security_group_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
