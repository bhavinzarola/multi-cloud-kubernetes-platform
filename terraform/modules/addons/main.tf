# NOTE: ArgoCD itself is bootstrapped via `kubectl apply` (see argocd/bootstrap and
# scripts/bootstrap.sh) rather than Terraform, to avoid a chicken-and-egg dependency
# where Terraform-managed Helm state fights with ArgoCD's own reconciliation of its
# Application CRDs. See docs/decisions.md for the full rationale. Everything else in
# this module IS installed via Terraform so the cluster is minimally viable before
# ArgoCD takes over ongoing app lifecycle via GitOps.

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.8.2"

  values = [yamlencode({
    clusterName = var.cluster_name
    serviceAccount = {
      create = true
      name   = "aws-load-balancer-controller"
      annotations = {
        "eks.amazonaws.com/role-arn" = var.lb_controller_role_arn
      }
    }
    region = data.aws_region.current.name
    vpcId  = var.vpc_id
  })]
}

data "aws_region" "current" {}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.12.2"

  values = [yamlencode({
    args = ["--kubelet-insecure-tls"]
  })]
}

resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = "external-secrets"
  }
}

resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  namespace  = kubernetes_namespace.external_secrets.metadata[0].name
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.external_secrets_version

  values = [yamlencode({
    serviceAccount = {
      create = true
      name   = "external-secrets"
      annotations = {
        "eks.amazonaws.com/role-arn" = var.external_secrets_role_arn
      }
    }
    installCRDs = true
  })]
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.kube_prometheus_stack_version

  values = [yamlencode({
    grafana = {
      adminPassword = var.grafana_admin_password
      persistence   = { enabled = true, size = "10Gi" }
    }
    prometheus = {
      prometheusSpec = {
        retention = "15d"
        storageSpec = {
          volumeClaimTemplate = {
            spec = {
              accessModes      = ["ReadWriteOnce"]
              resources        = { requests = { storage = "20Gi" } }
              storageClassName = "gp3"
            }
          }
        }
        serviceMonitorSelectorNilUsesHelmValues = false
      }
    }
    alertmanager = {
      alertmanagerSpec = {
        storage = {
          volumeClaimTemplate = {
            spec = {
              accessModes = ["ReadWriteOnce"]
              resources   = { requests = { storage = "5Gi" } }
            }
          }
        }
      }
    }
  })]
}

resource "helm_release" "loki_stack" {
  name       = "loki-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  version    = var.loki_stack_version

  values = [yamlencode({
    loki = {
      persistence = { enabled = true, size = "20Gi" }
    }
    promtail = { enabled = true }
    grafana  = { enabled = false } # Grafana already installed via kube-prometheus-stack
  })]

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "helm_release" "kyverno" {
  name             = "kyverno"
  namespace        = "kyverno"
  create_namespace = true
  repository       = "https://kyverno.github.io/kyverno/"
  chart            = "kyverno"
  version          = var.kyverno_version
}
