variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.30"
}

variable "vpc_id" {
  description = "VPC ID to deploy the cluster into"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the cluster and node groups"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs, used only if the public endpoint is enabled"
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Whether the EKS API server endpoint is publicly accessible (true for dev, false for prod)"
  type        = bool
  default     = true
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "system_node_instance_types" {
  description = "Instance types for the system managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "system_node_min_size" {
  type    = number
  default = 2
}

variable "system_node_max_size" {
  type    = number
  default = 3
}

variable "system_node_desired_size" {
  type    = number
  default = 2
}

variable "cluster_log_types" {
  description = "EKS control plane log types to ship to CloudWatch"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cluster_log_retention_days" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
