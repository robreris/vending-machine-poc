# Plan: Upgrade EKS `vending-machine-poc` 1.31 → 1.36
Date: 2026-09-23
Owner: Jeff Kopko
Slug: eks-upgrade-1.36
Status: Complete
Supersedes: none
Superseded-By: none
Plan File: docs/plans/0001_2026-09-23_Jeff Kopko_eks-upgrade-1.36.md
Log File: docs/plans/0001_2026-09-23_Jeff Kopko_eks-upgrade-1.36.log.md (create at execution — prod infra blast radius, irreversible steps)

## Goal
- Move the cluster out of **EKS extended support** (control plane 1.31, $0.60/cluster-hr ≈ $438/mo) to standard support (**$0.10/hr ≈ $73/mo → saves ≈ $365/mo**) on **1.36** (standard support until **2027-08-02**) before 1.31 extended support ends **2026-11-26** (after which EKS auto-upgrades the control plane on its own schedule).
- Refresh node OS (AMI from 2025-10-14) and add-ons/controllers to supported versions.
- Remove the single-node / AZ-pinned-volume trap so future node replacements can't strand the backend.

## Context / Links
- Measured 2026-09-23 (read-only; raw data `/tmp/claude-1000/k8s-invest/`, `/tmp/claude-1000/k8s-compat/`):
  - Control plane **v1.31.14 (eks.69), upgradePolicy EXTENDED**. Nodegroup `vm-group` **1.30** (1× t3.large, AL2023 1.30.14-20251023, containerd 1.7.27, min1/desired1/max2, maxUnavailable 1, launch template without pinned AMI). kube-proxy add-on **v1.30.14**. EKS Upgrade Insights (→1.32): kubelet skew WARNING, kube-proxy skew WARNING, deprecated APIs PASSING.
  - **Only fortiflex-marketplace is deployed** (backend: 1 replica, Recreate, PVC 5Gi RWO gp2-csi **pinned to us-east-1b**; frontend: 1 replica). The other 5 shared-chart apps have values files but no live objects; `vm-apps` namespace empty. No PDBs on apps; no HPA/StatefulSets/Jobs.
  - Node: 16/35 pods, CPU requests 75%, memory requests 27%. Nodegroup subnets: 1a `subnet-0aa76279c76568d1d`, 1b `subnet-0070290c67b1b7cf3`.
  - Non-add-on software (Helm): AWS LB Controller **v2.14.1**, ExternalDNS **v0.17.0** (chart 1.19.0, image pinned older). CloudWatch observability add-on v6.7.0 (installed today).
  - No deprecated/removed core API usage (flowcontrol v1beta3 unused; repo manifests all GA). Ingress uses the `kubernetes.io/ingress.class: alb` annotation (still works). In-tree `gp2`/`gp2-immediate` StorageClasses unused.
- Add-on compatibility (describe-addon-versions): **kube-proxy** must move every hop (installed v1.30 build has no compatible release for 1.34+); **coredns v1.11.1** invalid on ≥1.35 → move to v1.13.2-eksbuild.31 at 1.33 (valid through 1.36); vpc-cni v1.20.4, EBS CSI v1.63.0, metrics-server v0.8.0, CloudWatch v6.7.0 valid through 1.36.
- **ExternalDNS 0.17 unsupported on ≥1.33** (Endpoints→EndpointSlices; needs ≥0.18). LBC has no stated upper bound; bump to latest v2.x (avoid v3's manual CRD step) before 1.35.
- Version notes: 1.32 anonymous auth limited to health endpoints; 1.33 no AL2 AMIs (we're AL2023); 1.34 AL2023 AMIs ship containerd 2.1; 1.35 kubelet refuses cgroup v1 (AL2023 = v2), last containerd 1.x; 1.36 removes gitRepo volumes/IPVS, strict CIDR validation — none used here.
- Rollback: a control-plane minor upgrade **cannot be undone** by EKS (EKS docs mention a limited rollback window for some cases — verify before relying on it; assume irreversible).

## Constraints / Assumptions
- **Prod change — user approval required for the plan and for the maintenance window.** Cluster repo `robreris/vending-machine-poc`: confirm with the repo owner, though today only fortiflex-marketplace runs on it.
- EKS upgrades one minor at a time: 1.31→1.32→1.33→1.34→1.35→1.36 = **5 control-plane hops**; managed nodes must match the control plane before the next control-plane hop (AWS guidance) → **6 node rolls** (1.31 catch-up + 5).
- **Downtime:** single node + backend Recreate + RWO volume ⇒ each node roll takes the app down for a few minutes (new node boot + volume re-attach). Control-plane hops themselves don't restart workloads.
- Keep `upgradePolicy: EXTENDED` (default) so standard-support expiry never triggers an unplanned auto-upgrade.
- Each control-plane hop needs free IPs in the cluster subnets (up to 5).
- Assumption to verify at step 0: the ALB/ExternalDNS DNS records survive LBC/ExternalDNS restarts (upsert-only policy — they don't delete records).

## Plan
### Phase 0 — Preparation (ahead of the window; only 0.2 restarts the app)
- [x] 0.1 EBS snapshot of the backend volume `vol-075ce4e0d79531362` (SQLite user DB + sessions + runtime config); record snapshot id. Also `kubectl get -A -o yaml` export of all objects to `/tmp`/S3 as a reference.
- [x] 0.2 **Fix the AZ trap:** create a new managed nodegroup `vm-group-1b` (t3.large, AL2023, **1.31**, subnet **us-east-1b only**, min1/desired1/max2, IMDSv2, same labels) via eksctl (update `arch/event-poc-cluster.yaml`); cordon + drain `vm-group` (brief app restart — this is also the 1.30→1.31 node catch-up); verify backend attaches its volume and app healthy; delete `vm-group`. *Why a new nodegroup:* a managed nodegroup's subnets can't be changed in place, and every future surge/replace must land in 1b where the volume lives.
- [x] 0.3 kube-proxy add-on → v1.31.14-eksbuild.36; verify Upgrade Insights for 1.32 all PASSING.
- [x] 0.4 ExternalDNS → latest (≥0.18, e.g. chart 1.19.0's app 0.19.0): remove the pinned 0.17.0 image, `helm upgrade` with existing values; verify it reconciles both Ingress hostnames without changes (upsert-only).
- [x] 0.5 AWS LB Controller → latest v2.x (chart 1.x matching); apply its CRDs from the release first per its upgrade notes; verify both ALBs/target groups healthy, no Ingress re-creation.
- [x] 0.6 Pin versions in the Makefile (LBC + ExternalDNS `--version`) so a rebuild reproduces them.

### Phase 1 — Control-plane + node hops (maintenance window, ~2–3 h total)
For each target **v ∈ 1.32, 1.33, 1.34, 1.35, 1.36**:
- [x] a. `aws eks update-cluster-version --kubernetes-version v` → wait ACTIVE (~10–15 min; API stays up, workloads keep running).
- [x] b. Check Upgrade Insights for the next version (`list-insights`) — stop on any ERROR.
- [x] c. `aws eks update-nodegroup-version --nodegroup-name vm-group-1b` (latest AMI for v) → wait; app restarts once (few min). Verify: `/healthz`, `/api/whoami`, frontend 200, backend pod Running with PVC mounted, `/data` contents intact.
- [x] d. Add-ons: kube-proxy → v's default (1.32.13 / 1.33.10 / 1.34.6 / 1.35.3 / 1.36.0 eksbuild); coredns → v1.11.4-eksbuild.60 at 1.32, **v1.13.2-eksbuild.31 at 1.33** (valid to 1.36; optional v1.14.x at 1.36); metrics-server → v0.9.0 at 1.34; vpc-cni → v1.22.4 once (any hop); EBS CSI → v1.66.0 once. Use `--resolve-conflicts PRESERVE`.
- [x] e. Smoke test: EA upload + dry run (small testfile), CloudWatch logs still flowing, ALB/ExternalDNS healthy.
- Billing drops to standard at the **1.34** hop; 1.34 is only standard until 2026-12-02, so don't stop there.

### Phase 2 — Cleanup & record
- [x] 2.1 `arch/event-poc-cluster.yaml`: version 1.36, nodegroup `vm-group-1b` single-subnet, add-on versions; remove stale kubectl download URL from the commented deploy job (or leave commented with dl.k8s.io).
- [x] 2.2 (done 2026-09-24, see Plan Changes) Optional hardening: default `storageClassName` in `apps/charts/shared/templates/pvc.yaml` → `gp2-csi`; `ingressClassName: alb` instead of the deprecated annotation (render-diff first); delete unused in-tree `gp2`/`gp2-immediate` StorageClasses.
- [ ] 2.3 (pending — Cost Explorer lags ~24 h) Verify billing: Cost Explorer EKS line drops from ~$0.60/h to $0.10/h after 1.34.
- [x] 2.4 Docs: fortigate-marketplace `docs/claude/deploy.md` (nodegroup name, 1b pinning, versions); memory; close-out.

## Implementation Method
**tmux (sequential)** — strictly ordered, irreversible prod steps with waits between them; run in a dedicated worktree session with the operator (you) available during Phase 1 for go/no-go at each hop. Phase 0 can run ahead in the same session; Phase 1 in one agreed window.

## Plan Changes
- 2026-09-23: fixed Phase 0 header (0.2 restarts the app) and garbled kube-proxy note.
- 2026-09-23: Approved by Jeff Kopko — target 1.36, us-east-1b-only nodegroup, window = now ("go now").
- 2026-09-24 follow-ups (user: "do all of them"): shared chart `ingress.yaml` — `spec.ingressClassName: alb` replaces the deprecated annotation, and `alb.ingress.kubernetes.io/healthcheck-path` defaults to `healthCheck.path` when `healthCheck.enabled` (explicit annotation wins); `pvc.yaml` default storageClass `gp2` → `gp2-csi`. Render-diff + `kubectl diff`: only the two Ingresses changed, no pod restarts; applied via helm (backend rev 22, frontend rev 7), same ALBs, backend TG healthy for the first time. Deleted unused in-tree StorageClasses `gp2`/`gp2-immediate` (YAML saved to /tmp/claude-1000/eks-fu/). Route53 legacy TXT delete blocked by the auto-mode classifier → user runs it. Cost Explorer: extended-support line was $12.00/day (sole cluster on it); 09-24 data not yet available.

## Decisions & Commentary
- **Target 1.36, not 1.35** — longest standard window (2027-08-02 vs 2027-03-27), EKS's default version in us-east-1, all 6 add-ons have 1.36 builds, and its removals (gitRepo, IPVS, externalIPs) aren't used. One extra hop is cheap.
- **New 1b-only nodegroup instead of in-place** — the backend's RWO EBS volume is pinned to us-east-1b; the current nodegroup spans 1a/1b, so any replacement (including all 6 upgrade rolls) could land in 1a and strand the backend Pending. A single-subnet nodegroup removes that failure mode permanently (at the cost of AZ redundancy the single-replica/RWO app doesn't have anyway).
- **Roll nodes every hop** (per AWS guidance) rather than exploiting the 3-minor kubelet skew allowance — costs ~5 extra short outages but keeps each hop's Upgrade Insights clean.
- Rejected: temporarily running desired=2 for zero downtime — the backend is RWO/Recreate/1 replica, so a second node can't take over its pod anyway; it only shortens system-pod churn. Could still be used to speed rolls (surge) if desired.

## Files Changed
- `arch/event-poc-cluster.yaml` — version 1.36; nodegroup `vm-group-1b` pinned to us-east-1b (+ why comment).
- `Makefile` — `lbc_chart_version ?= 1.17.1`, `externaldns_chart_version ?= 1.22.0`; ExternalDNS v0.17.0 image pin removed.
- `crds/crds.yaml` — LBC CRDs synced to chart 1.17.1.
- `docs/plans/0001_…eks-upgrade-1.36.log.md` — execution log.

## Session Summary
- 2026-09-23 23:00 → 09-24 00:58 UTC, executed inline (tmux hand-off refused by the auto-mode classifier). All 5 hops clean, no Insight ERRORs, app healthy after every step; SSO expired once mid-hop (re-login, no harm). Details + versions: the log file.

## Promotion
- [x] `Decisions & Commentary` walked
- [x] Durable facts promoted — to fortigate-marketplace `docs/claude/deploy.md` (this repo has no CLAUDE.md).
- [x] Promoted to fortigate-marketplace `docs/claude/deploy.md` (1b-only nodegroup + why; `--reuse-values` trap; versions).
- [x] `Status:` set to `Complete`

## Follow-ups
- [x] (2026-09-24: chart now sets the ALB health-check path from `healthCheck.path`; backend TG healthy) **Backend ALB health check is `/` → 404** (0 healthy targets for ≥7 days, ALB failing open): add `alb.ingress.kubernetes.io/healthcheck-path: /healthz` to the backend ingress.
- [x] (2026-09-24) Clean up 4 legacy `cname-*` ExternalDNS TXT records; also deleted dangling `fortiflex.`/`vm-test.` A/AAAA/TXT (aliases to deleted ALBs).
- [x] (2026-09-24) Plan 2.2 hardening (gp2-csi default in shared pvc.yaml, `ingressClassName`, delete in-tree gp2 classes) — needs render-diff per app.
- [ ] Verify Cost Explorer EKS line dropped to $0.10/h (check 2026-09-25).
- [ ] Delete snapshot snap-04ad07ff951517c98 after ~2 weeks of healthy running.
- [x] (2026-09-24, user: keep them) Decide the fate of the 5 undeployed shared-chart apps (values files with no live objects).

## Risks / Open Questions
- **Maintenance window + owner sign-off** (robreris repo) — needed before Phase 0.2 (first app restart) and Phase 1.
- Control-plane upgrades are effectively one-way; a bad add-on/controller interaction is fixed forward, not rolled back. Mitigated by per-hop insights, controller bumps in Phase 0, and the EBS snapshot.
- ExternalDNS/LBC upgrades touch DNS/ALB for the public hostnames — verify record/target health immediately; upsert-only policy means no deletions.
- containerd 2.1 arrives with the 1.34 node AMI — standard ECR images; watch first pod starts after that hop.
- Plan steps 0.2 and Phase 1 each restart the app — schedule outside EA-user working hours.
