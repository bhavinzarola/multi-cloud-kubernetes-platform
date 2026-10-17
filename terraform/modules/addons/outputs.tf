output "monitoring_namespace" {
  value = kubernetes_namespace.monitoring.metadata[0].name
}

output "external_secrets_namespace" {
  value = kubernetes_namespace.external_secrets.metadata[0].name
}

output "grafana_hint" {
  value       = "Run `make port-forward-grafana` and log in with user 'admin'"
  description = "Reminder of how to access Grafana"
}
