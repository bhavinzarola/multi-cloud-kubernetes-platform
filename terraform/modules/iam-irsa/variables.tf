variable "role_name" {
  description = "Name of the IAM role"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster's OIDC provider"
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC provider URL without the https:// prefix"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace of the service account"
  type        = string
}

variable "service_account" {
  description = "Kubernetes service account name that will assume this role"
  type        = string
}

variable "policy_arns" {
  description = "List of managed policy ARNs to attach"
  type        = list(string)
  default     = []
}

variable "policy_json" {
  description = "Inline JSON policy document to attach (optional)"
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
