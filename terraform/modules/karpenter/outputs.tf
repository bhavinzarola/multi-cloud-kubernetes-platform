output "karpenter_release_name" {
  value = helm_release.karpenter.name
}

output "karpenter_release_status" {
  value = helm_release.karpenter.status
}
