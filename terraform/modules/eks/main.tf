locals {
  addon_versions = {
    vpc_cni               = "v1.18.3-eksbuild.1"
    coredns               = "v1.11.3-eksbuild.1"
    kube_proxy            = "v1.30.3-eksbuild.5"
    aws_ebs_csi_driver    = "v1.35.0-eksbuild.1"
    eks_pod_identity_agent = "v1.3.2-eksbuild.2"
  }
}

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cluster_log_retention_days
  tags              = var.tags
}

resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Additional security group for the EKS control plane ENIs"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.cluster_name}-cluster-sg" })
}

resource "aws_eks_cluster" "this" {
  name                      = var.cluster_name
  role_arn                  = aws_iam_role.cluster.arn
  version                   = var.cluster_version
  enabled_cluster_log_types = var.cluster_log_types

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access ? var.endpoint_public_access_cidrs : null
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_cloudwatch_log_group.cluster,
  ]

  tags = var.tags
}

# --- Managed system node group ---
resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-system"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = var.system_node_instance_types
  capacity_type  = "ON_DEMAND"

  scaling_config {
    min_size     = var.system_node_min_size
    max_size     = var.system_node_max_size
    desired_size = var.system_node_desired_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    "node-pool" = "system"
  }

  taint {
    key    = "CriticalAddonsOnly"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_group_policies,
  ]

  tags = merge(var.tags, {
    "karpenter.sh/discovery" = var.cluster_name
  })
}

# --- EKS Addons ---
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  addon_version               = local.addon_versions.vpc_cni
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  addon_version               = local.addon_versions.coredns
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.system]
  tags                        = var.tags
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  addon_version               = local.addon_versions.kube_proxy
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = local.addon_versions.aws_ebs_csi_driver
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = module.irsa_ebs_csi_role.role_arn
  depends_on                  = [aws_eks_node_group.system]
  tags                        = var.tags
}

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "eks-pod-identity-agent"
  addon_version               = local.addon_versions.eks_pod_identity_agent
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags
}

# --- IRSA roles for the platform controllers ---
module "irsa_ebs_csi_role" {
  source            = "../iam-irsa"
  role_name         = "${var.cluster_name}-ebs-csi-irsa"
  oidc_provider_arn = aws_iam_openid_connect_provider.eks.arn
  oidc_provider_url = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
  namespace         = "kube-system"
  service_account   = "ebs-csi-controller-sa"
  policy_arns       = ["arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"]
  tags              = var.tags
}

module "irsa_lb_controller" {
  source            = "../iam-irsa"
  role_name         = "${var.cluster_name}-lb-controller-irsa"
  oidc_provider_arn = aws_iam_openid_connect_provider.eks.arn
  oidc_provider_url = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
  namespace         = "kube-system"
  service_account   = "aws-load-balancer-controller"
  policy_json       = file("${path.module}/policies/aws-load-balancer-controller-policy.json")
  tags              = var.tags
}

module "irsa_external_secrets" {
  source            = "../iam-irsa"
  role_name         = "${var.cluster_name}-external-secrets-irsa"
  oidc_provider_arn = aws_iam_openid_connect_provider.eks.arn
  oidc_provider_url = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
  namespace         = "external-secrets"
  service_account   = "external-secrets"
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = "arn:${data.aws_partition.current.partition}:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:eks-demo-app/*"
    }]
  })
  tags = var.tags
}

module "irsa_karpenter" {
  source            = "../iam-irsa"
  role_name         = "${var.cluster_name}-karpenter-irsa"
  oidc_provider_arn = aws_iam_openid_connect_provider.eks.arn
  oidc_provider_url = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
  namespace         = "kube-system"
  service_account   = "karpenter"
  policy_json       = file("${path.module}/policies/karpenter-controller-policy.json")
  tags              = var.tags
}
