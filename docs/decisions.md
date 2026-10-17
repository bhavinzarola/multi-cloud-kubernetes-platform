# Architecture Decision Records (ADRs)

## ADR-001: Karpenter over Cluster Autoscaler

**Status:** Accepted

**Context:** The platform needs to scale worker nodes to match pod demand,
including opportunistic use of Spot capacity to reduce cost.

**Decision:** Use Karpenter instead of the Kubernetes Cluster Autoscaler.

**Rationale:**

- Karpenter provisions nodes directly via the EC2 Fleet API rather than
  scaling pre-defined Auto Scaling Groups, so it can bin-pack pods onto the
  cheapest instance shape that fits, across many instance families/sizes,
  without pre-defining an ASG per shape.
- Native Spot support with automatic fallback to On-Demand and graceful
  handling of Spot interruption notices.
- Faster scale-up (seconds, not minutes) because it skips the ASG's own
  scaling cool-downs.
- Declarative `NodePool`/`EC2NodeClass` CRDs fit naturally into the GitOps
  model already used for the rest of the platform.

**Trade-offs:** Karpenter is AWS/cloud-provider specific (not portable to other
clouds the way Cluster Autoscaler's cloud-provider abstraction is), and it is a
newer, faster-moving project than Cluster Autoscaler.

---

## ADR-002: ArgoCD over Flux

**Status:** Accepted

**Context:** The platform needs a GitOps continuous-delivery controller to
reconcile cluster state from Git.

**Decision:** Use ArgoCD.

**Rationale:**

- Rich Web UI and CLI make sync status, drift, and rollback history easy to
  demonstrate to reviewers/interviewers, and easy to debug in an incident.
- The app-of-apps pattern maps cleanly onto this repo's `argocd/apps/`
  directory, giving a single entry point for every managed component.
- Broad adoption in the target job market for this repo (AWS DevOps / Platform
  Engineer roles frequently list ArgoCD specifically).

**Trade-offs:** Flux's `kustomize-controller`/`helm-controller` split and
notification-controller are arguably more Kubernetes-native (pure CRDs, no
separate UI/API server to run), and some teams prefer Flux's smaller footprint.
Either is a reasonable choice; this repo optimizes for demoability.

---

## ADR-003: External Secrets Operator over Sealed Secrets

**Status:** Accepted

**Context:** Secrets (DB credentials, API keys) must never be committed to
Git, but the cluster needs a way to consume them.

**Decision:** Use External Secrets Operator (ESO) backed by AWS Secrets
Manager, rather than Bitnami Sealed Secrets.

**Rationale:**

- ESO keeps the **source of truth in AWS Secrets Manager**, which already has
  rotation, audit logging (CloudTrail), and fine-grained IAM access control —
  Sealed Secrets would require a separate secret lifecycle/rotation story.
- IRSA-based auth (`ExternalSecret` → `SecretStore` → IRSA role) means no
  cluster-wide keypair (as Sealed Secrets' controller key is) to protect.
- Secrets can be shared/rotated centrally across multiple clusters/environments
  without re-encrypting and re-committing anything to Git.

**Trade-offs:** ESO requires network access to AWS Secrets Manager and an
extra controller running in-cluster; Sealed Secrets has no external
dependency and works fully offline/air-gapped, which is a real advantage in
some environments.

---

## ADR-004: Single AWS account by default; multi-account as a documented extension

**Status:** Accepted

**Context:** Many production setups isolate `dev`/`staging`/`prod` into
separate AWS accounts (AWS Organizations + account vending), but that adds
real complexity (cross-account IAM, ECR replication, account-level Terraform
backends) that isn't necessary to demonstrate the platform's core skills.

**Decision:** Ship a single-account reference deployment (with `dev` and
`prod` as **separate VPCs/clusters within one account**, distinguished by
Terraform environment and resource naming), and document multi-account as an
extension rather than implementing it.

**Rationale:**

- Keeps the reference deployment cheap, fast to bootstrap/destroy, and easy
  for a reviewer to run end-to-end in one account.
- The ECR module already supports `cross_account_read_principals` as a
  building block toward a multi-account image-promotion pattern.
- A real multi-account rollout is largely an exercise in AWS Organizations,
  account vending, and cross-account IAM trust — orthogonal to the EKS/GitOps
  patterns this repo focuses on demonstrating.

**Extension path:** to go multi-account, split `terraform/environments/dev`
and `prod` into separate backend configs pointed at per-account S3 buckets,
assume a cross-account role from CI per environment, and grant the `prod`
account's node/IRSA roles pull access to a shared or replicated ECR repo via
`cross_account_read_principals`.

---

## ADR-005: ArgoCD's own install is bootstrapped via `kubectl apply`, not Terraform or an ArgoCD Application

**Status:** Accepted

**Context:** Something has to install ArgoCD before ArgoCD can start managing
anything via GitOps — this is the classic "who bootstraps the bootstrapper"
problem. Terraform's `helm_release`/`kubectl_manifest` resources *could*
install ArgoCD, but then ArgoCD's own upgrades would be split between two
reconcilers (Terraform state and ArgoCD's own sync) fighting over the same
resources.

**Decision:** Install ArgoCD via a plain `kubectl apply -f
<upstream-install.yaml>` in `scripts/bootstrap.sh`. Terraform provisions every
*other* platform add-on directly (see `terraform/modules/addons`) to get the
cluster to a working baseline; the ArgoCD `Application` manifests in
`argocd/apps/` then take over **ongoing** reconciliation of those same
add-ons (and the demo app) going forward, so that post-bootstrap drift
self-heals from Git rather than from Terraform state.

**Rationale:** clean separation of "day 0" bootstrap (Terraform: get a
minimally viable cluster) from "day 1+" operations (ArgoCD: everything is
governed by Git from here on). Avoids a circular dependency where Terraform
depends on ArgoCD's CRDs (which don't exist until ArgoCD is installed) and
ArgoCD depends on Terraform-created IAM/IRSA resources.

**Trade-offs:** the same Helm chart (e.g. `kube-prometheus-stack`) briefly
exists as both a Terraform-managed `helm_release` and an ArgoCD `Application`
targeting the same release name/namespace. In practice, once ArgoCD's
`selfHeal: true` sync takes over, its reconciliation supersedes Terraform's
for that release; a follow-up hardening step (not included here, to keep the
repo simple to run) would be to `terraform state rm` those `helm_release`
resources once ArgoCD has adopted them, so exactly one controller owns each
resource going forward.
