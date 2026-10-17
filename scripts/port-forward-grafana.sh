#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-monitoring}"
RELEASE="${2:-kube-prometheus-stack}"
LOCAL_PORT="${3:-3000}"

echo "==> Fetching Grafana admin password..."
GRAFANA_PWD="$(kubectl -n "${NAMESPACE}" get secret "${RELEASE}-grafana" -o jsonpath='{.data.admin-password}' | base64 -d)"

echo "-----------------------------------------------------------------"
echo " Grafana URL:      http://localhost:${LOCAL_PORT}"
echo " Grafana user:     admin"
echo " Grafana password: ${GRAFANA_PWD}"
echo "-----------------------------------------------------------------"
echo "==> Port-forwarding (Ctrl+C to stop)..."
kubectl -n "${NAMESPACE}" port-forward "svc/${RELEASE}-grafana" "${LOCAL_PORT}:80"
