resource "helm_release" "karpenter" {
  name             = "karpenter"
  namespace        = "kube-system"
  create_namespace = false
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = var.karpenter_version

  values = [yamlencode({
    serviceAccount = {
      annotations = {
        "eks.amazonaws.com/role-arn" = var.karpenter_role_arn
      }
    }
    settings = {
      clusterName       = var.cluster_name
      clusterEndpoint   = var.cluster_endpoint
      interruptionQueue = "${var.cluster_name}-karpenter"
    }
    controller = {
      resources = {
        requests = { cpu = "1", memory = "1Gi" }
        limits   = { memory = "1Gi" }
      }
    }
    tolerations = [{
      key      = "CriticalAddonsOnly"
      operator = "Exists"
    }]
  })]
}

# NodePool: general-purpose workloads (On-Demand + Spot)
resource "kubectl_manifest" "nodepool_general_purpose" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: general-purpose
    spec:
      template:
        metadata:
          labels:
            node-pool: general-purpose
        spec:
          requirements:
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["spot", "on-demand"]
            - key: karpenter.k8s.aws/instance-category
              operator: In
              values: ["c", "m", "r"]
            - key: karpenter.k8s.aws/instance-generation
              operator: Gt
              values: ["4"]
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default
          expireAfter: 720h
      limits:
        cpu: "100"
        memory: 400Gi
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 1m
        budgets:
          - nodes: "10%"
  YAML

  depends_on = [helm_release.karpenter]
}

# NodePool: system workloads that must stay On-Demand
resource "kubectl_manifest" "nodepool_system" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: system
    spec:
      template:
        metadata:
          labels:
            node-pool: system
        spec:
          requirements:
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["on-demand"]
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default
          taints:
            - key: CriticalAddonsOnly
              effect: NoSchedule
      limits:
        cpu: "20"
        memory: 80Gi
      disruption:
        consolidationPolicy: WhenEmpty
        consolidateAfter: 10m
        budgets:
          - nodes: "1"
  YAML

  depends_on = [helm_release.karpenter]
}

resource "kubectl_manifest" "ec2nodeclass_default" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: AL2023
      role: ${replace(var.node_instance_profile_name, "-instance-profile", "-role")}
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${var.cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${var.cluster_name}
      tags:
        karpenter.sh/discovery: ${var.cluster_name}
        Project: eks-platform-gitops
        ManagedBy: karpenter
      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: 50Gi
            volumeType: gp3
            encrypted: true
            deleteOnTermination: true
  YAML

  depends_on = [helm_release.karpenter]
}
