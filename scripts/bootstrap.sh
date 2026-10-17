#!/usr/bin/env bash
set -euo pipefail

ENV="${1:-dev}"
AWS_REGION="${AWS_REGION:-eu-west-1}"
ARGOCD_VERSION="v2.12.6"
TF_DIR="terraform/environments/${ENV}"

echo "==> Bootstrapping eks-platform-gitops [env=${ENV}, region=${AWS_REGION}]"

command -v terraform >/dev/null || { echo "terraform is required"; exit 1; }
command -v kubectl >/dev/null || { echo "kubectl is required"; exit 1; }
command -v aws >/dev/null || { echo "aws cli is required"; exit 1; }

echo "==> [1/5] terraform init/apply (VPC, EKS, Karpenter, core add-ons)"
pushd "${TF_DIR}" >/dev/null
terraform init -upgrade
terraform apply -auto-approve
CLUSTER_NAME="$(terraform output -raw cluster_name)"
popd >/dev/null

echo "==> [2/5] Configuring kubectl for cluster '${CLUSTER_NAME}'"
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}"

echo "==> [3/5] Installing ArgoCD (${ARGOCD_VERSION}) via kubectl apply"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
echo "    waiting for argocd-server to be ready..."
kubectl -n argocd rollout status deployment/argocd-server --timeout=300s

echo "==> [4/5] Applying the app-of-apps"
kubectl apply -f argocd/apps/app-of-apps.yaml

echo "==> [5/5] Done. Useful info:"
ARGOCD_PWD="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
echo "-----------------------------------------------------------------"
echo " Cluster:        ${CLUSTER_NAME}"
echo " ArgoCD URL:      kubectl -n argocd port-forward svc/argocd-server 8080:443"
echo " ArgoCD user:     admin"
echo " ArgoCD password: ${ARGOCD_PWD}"
echo " Grafana:         make port-forward-grafana"
echo "-----------------------------------------------------------------"
echo " Remember: run 'make destroy ENV=${ENV}' when you're done to avoid ongoing AWS charges."
