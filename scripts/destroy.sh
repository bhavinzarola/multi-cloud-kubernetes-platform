#!/usr/bin/env bash
set -euo pipefail

ENV="${1:-dev}"
AWS_REGION="${AWS_REGION:-eu-west-1}"
TF_DIR="terraform/environments/${ENV}"

echo "==> Destroying eks-platform-gitops [env=${ENV}, region=${AWS_REGION}]"
echo "    This will delete the EKS cluster, VPC, and all associated resources."
read -r -p "Type the environment name (${ENV}) to confirm: " CONFIRM
if [[ "${CONFIRM}" != "${ENV}" ]]; then
  echo "Confirmation did not match. Aborting."
  exit 1
fi

if kubectl config current-context >/dev/null 2>&1; then
  echo "==> [1/3] Deleting ArgoCD-managed Applications first (so ALBs/EBS volumes are cleaned up)"
  kubectl delete applications.argoproj.io --all -n argocd --ignore-not-found=true --wait=true --timeout=180s || true
  kubectl delete namespace eks-demo-app --ignore-not-found=true --wait=true --timeout=180s || true

  echo "==> [2/3] Removing ArgoCD itself"
  kubectl delete namespace argocd --ignore-not-found=true --wait=true --timeout=180s || true
else
  echo "==> No active kubectl context found, skipping in-cluster cleanup"
fi

echo "==> [3/3] terraform destroy"
pushd "${TF_DIR}" >/dev/null
terraform init -upgrade
terraform destroy -auto-approve
popd >/dev/null

echo "==> Destroy complete. Double check the AWS console for any orphaned"
echo "    Load Balancers, EBS volumes, or Elastic IPs that may continue to bill."
