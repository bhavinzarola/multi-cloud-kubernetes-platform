variable "name" {
  description = "Name prefix for all VPC resources"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to deploy subnets into (3 recommended)"
  type        = list(string)
}

variable "cluster_name" {
  description = "EKS cluster name, used for the kubernetes.io/cluster/<name> subnet tag"
  type        = string
}

variable "single_nat_gateway" {
  description = "If true, create a single shared NAT Gateway (dev). If false, one NAT Gateway per AZ (prod)."
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs to CloudWatch"
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "CloudWatch log group retention for VPC flow logs"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
