# Runbook: Common Incidents & Fixes

## 1. Node not joining the cluster

**Symptoms:** `kubectl get nodes` doesn't show a newly launched EC2 instance;
the instance is running in the AWS console but never becomes `Ready`.

**Likely causes & fixes:**

- **IAM/aws-auth mismatch** — the node's IAM role isn't mapped in the cluster's
  access entries. Check:
  ```bash
  aws eks list-access-entries --cluster-name <cluster>
  aws eks describe-access-entry --cluster-name <cluster> --principal-arn <node-role-arn>
  ```
  This platform uses EKS API-based access entries (`authentication_mode =
  "API_AND_CONFIG_MAP"`); confirm the node role from `terraform output
  node_group_role_arn` (or the Karpenter node role) has an access entry with
  the `AmazonEKSAutoNodePolicy`/worker policy type.

- **Security group / networking** — the node's security group must allow
  outbound HTTPS to the cluster endpoint and node-to-node traffic. Check the
  `karpenter.sh/discovery` tag matches the cluster name on both subnets and
  security groups (Karpenter's `EC2NodeClass` selects them by this tag).

- **kubelet/containerd logs** — SSM into the instance (no SSH needed, thanks to
  `AmazonSSMManagedInstanceCore` on the node role):
  ```bash
  aws ssm start-session --target <instance-id>
  sudo journalctl -u kubelet -n 200 --no-pager
  ```

- **Karpenter-provisioned node stuck** — check Karpenter's own logs:
  ```bash
  kubectl -n kube-system logs -l app.kubernetes.io/name=karpenter -f
  ```
  Common cause: no `EC2NodeClass`/`NodePool` matches the pending pod's
  requirements (e.g. an `nodeSelector` for an instance type Karpenter's
  `NodePool.requirements` excludes).

## 2. Pod stuck in `Pending`

**Symptoms:** `kubectl get pods -n eks-demo-app` shows a pod stuck in
`Pending` for more than a minute or two.

**Diagnosis:**

```bash
kubectl describe pod <pod> -n eks-demo-app
```

Look at the `Events` section for the actual scheduler complaint:

- `Insufficient cpu` / `Insufficient memory` — Karpenter should provision a new
  node within ~30-60s if a matching `NodePool` exists. If it doesn't:
  ```bash
  kubectl get nodepools
  kubectl get ec2nodeclass default -o yaml
  kubectl -n kube-system logs -l app.kubernetes.io/name=karpenter --tail=100
  ```
- `node(s) had taint {CriticalAddonsOnly: true}` — a workload without the
  matching toleration is trying to schedule on the tainted system node group;
  this is expected — it should instead land on a `general-purpose` Karpenter
  node.
- `PodDisruptionBudget` blocking eviction during a rollout — check
  `kubectl get pdb -n eks-demo-app`.
- Image pull errors — verify the ECR repository policy and that the node's
  IAM role has `AmazonEC2ContainerRegistryReadOnly` (it does, by default, via
  `terraform/modules/eks/iam.tf`).

## 3. ALB not provisioning

**Symptoms:** `kubectl get ingress -n eks-demo-app` shows no `ADDRESS`, or the
ALB never appears in the EC2 console.

**Diagnosis:**

```bash
kubectl -n kube-system logs -l app.kubernetes.io/name=aws-load-balancer-controller --tail=200
kubectl describe ingress eks-demo-app -n eks-demo-app
```

**Common causes:**

- **Missing subnet tags** — the AWS Load Balancer Controller discovers subnets
  via `kubernetes.io/role/elb` (public) and `kubernetes.io/role/internal-elb`
  (private) tags. Confirm these exist on the VPC's subnets (set by
  `terraform/modules/vpc`).
- **IRSA misconfiguration** — check the controller's ServiceAccount has the
  correct `eks.amazonaws.com/role-arn` annotation and that the IAM policy
  (`terraform/modules/eks/policies/aws-load-balancer-controller-policy.json`)
  is attached.
- **`ingressClassName` mismatch** — the chart's `values.yaml` sets
  `ingress.className: alb`; confirm an `IngressClass` named `alb` exists
  (the controller creates one by default) and the annotation
  `alb.ingress.kubernetes.io/*` keys are spelled correctly.
- **ACM certificate not validated (prod only)** — `values-prod.yaml`
  references `alb.ingress.kubernetes.io/certificate-arn`; an unvalidated or
  wrong-region ACM cert will silently block listener creation.

## 4. ArgoCD Application stuck `OutOfSync` / `Degraded`

**Symptoms:** `kubectl get applications -n argocd` shows a non-`Synced` or
non-`Healthy` status that doesn't resolve on its own.

**Diagnosis:**

```bash
argocd app get <app-name>
argocd app diff <app-name>
kubectl -n argocd logs deploy/argocd-application-controller --tail=200
```

**Common causes:**

- **Manual `kubectl edit`/`kubectl patch` drift** — with `selfHeal: true`,
  ArgoCD should revert this automatically within ~3 minutes (its default
  reconciliation interval); if it doesn't, check `argocd app get <app-name>`
  for sync errors (e.g. an admission webhook — Kyverno — is rejecting the
  reverted resource).
- **Helm values drift** — if `values-dev.yaml` was hand-edited in-cluster via
  `helm upgrade` outside of ArgoCD, the next Git-driven sync will overwrite it;
  this is intended behavior for a GitOps-managed resource.
- **CRDs not yet installed** — a fresh `kube-prometheus-stack` sync can fail
  the first time if `ServiceMonitor` CRDs aren't present yet; re-sync after
  the CRD-installing sync wave completes, or set `syncOptions:
  ["ServerSideApply=true"]` for the app.
- **Repeated retry/backoff exhausted** — check `spec.syncPolicy.retry` on the
  `Application`; increase `limit`/`maxDuration` for slow-converging Helm
  charts (e.g. `kube-prometheus-stack` on first install).

## Escalation

If none of the above resolves the issue, capture:

- `kubectl get events -A --sort-by='.lastTimestamp' | tail -100`
- `kubectl -n argocd logs deploy/argocd-application-controller --tail=500`
- Output of `terraform plan` in the affected environment (to rule out drift
  between Terraform state and reality)

...and escalate to the platform team with the above attached.
