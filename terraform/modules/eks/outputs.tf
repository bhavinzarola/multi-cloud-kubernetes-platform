output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_arn" {
  value = aws_eks_cluster.this.arn
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  value = aws_iam_openid_connect_provider.eks.url
}

output "node_group_role_arn" {
  value = aws_iam_role.node_group.arn
}

output "lb_controller_role_arn" {
  value = module.irsa_lb_controller.role_arn
}

output "external_secrets_role_arn" {
  value = module.irsa_external_secrets.role_arn
}

output "karpenter_role_arn" {
  value = module.irsa_karpenter.role_arn
}

output "cluster_security_group_id" {
  value = aws_security_group.cluster.id
}
