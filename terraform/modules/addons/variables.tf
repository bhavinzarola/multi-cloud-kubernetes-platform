variable "cluster_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "lb_controller_role_arn" {
  type = string
}

variable "external_secrets_role_arn" {
  type = string
}

variable "argocd_version" {
  type    = string
  default = "7.6.12" # argo-helm chart version pinning ArgoCD v2.12+
}

variable "kube_prometheus_stack_version" {
  type    = string
  default = "62.7.0"
}

variable "loki_stack_version" {
  type    = string
  default = "2.10.2"
}

variable "external_secrets_version" {
  type    = string
  default = "0.9.20"
}

variable "kyverno_version" {
  type    = string
  default = "3.2.6"
}

variable "grafana_admin_password" {
  description = "Initial Grafana admin password (rotate via Secrets Manager in real use)"
  type        = string
  sensitive   = true
  default     = "changeme-in-secrets-manager"
}

variable "tags" {
  type    = map(string)
  default = {}
}
