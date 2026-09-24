# Session Log: EKS upgrade 1.31 → 1.36
Date: 2026-09-23
Owner: Jeff Kopko
Related Plan: docs/plans/0001_2026-09-23_Jeff Kopko_eks-upgrade-1.36.md

Executed inline from the orchestrating Claude session (the tmux hand-off to an unattended `--dangerously-skip-permissions` session was refused by the auto-mode classifier as a protected-scope IaC apply). All times UTC.

## Timeline
- 23:0x — EBS snapshot **snap-04ad07ff951517c98** of vol-075ce4e0d79531362. `/data` baseline: app 124K, marketplace.db 24K, 7 ea-sessions. Object export in `/tmp/claude-1000/eks-upgrade/cluster-export.yaml`.
- 23:06–23:08 — `eksctl create nodegroup` **vm-group-1b** (t3.large, AL2023, 1.31, subnet-0070290c67b1b7cf3 only). Node ip-10-0-101-50 Ready v1.31.14.
- 23:08:46 — cordon + drain old vm-group node (metrics-server / ebs-csi PDBs retried, then evicted). Backend + frontend Ready on the new node by 23:10:03 (**~80 s app outage**). api/frontend 200, `/data` identical to baseline.
- 23:10 — `eksctl delete nodegroup vm-group` (background, exit 0).
- 23:10 — kube-proxy add-on v1.30.14 → **v1.31.14-eksbuild.36**.
- 23:11 — ExternalDNS chart 1.19.0 → **1.22.0** (image v0.17.0 pin removed → v0.22.0). Render-diff beforehand: only image changed. It migrated its TXT registry records to the new `a-` prefix and re-UPSERTed the same A-alias records; DNS and both hostnames verified.
- 23:12 — LBC CRDs applied server-side from chart 1.17.1; `helm upgrade --reuse-values` to chart 1.17.1 **did not change the image** (helm v4 reused the old chart's computed `image.tag` v2.14.1). Re-ran with `-f <user-supplied values>` → **v2.17.1**, 2/2 Ready, no errors.
- 23:15:46 → 23:26:49 — control plane **1.31 → 1.32** (eks.54).
- 23:27:12 → 23:33:55 — vm-group-1b rolled to **1.32.13** (managed surge; new node in 1b; containerd 2.2.7 already on these AL2023 AMIs). kube-proxy → v1.32.13-eksbuild.32, coredns v1.11.1 → v1.11.4-eksbuild.60. api/frontend 200, `/data` intact (ea-sessions 7 → 9 = live users).
- 23:37 → 23:51:47 — control plane **1.33** (eks.47). 23:51:50 → 23:57:31 nodes **1.33.13** (1b). kube-proxy → v1.33.10-eksbuild.29, coredns → v1.12.4-eksbuild.38. Health 200/200, `/data` intact, ExternalDNS no errors on EndpointSlices.
- 00:01:48 (09-24) — control plane **1.34** (eks.33). SSO token expired mid-wait (wait loop exited on the auth error, not on completion); re-login via device code, confirmed 1.34 ACTIVE. Nothing else was issued while unauthenticated.
- 00:12:36 → 00:19:19 — nodes **1.34.11** (1b). kube-proxy → v1.34.6-eksbuild.29 (coredns v1.12.4 already default). Health 200/200, `/data` intact. **Standard-support pricing from here.**
- 00:23–00:26 — one-time add-on bumps: metrics-server v0.8.0 → **v0.9.0-eksbuild.11**, EBS CSI v1.63.0 → **v1.66.0-eksbuild.1**, vpc-cni v1.20.4 → **v1.22.4-eksbuild.3**. `kubectl top` OK, health 200/200. CloudWatch observability v6.7.0 is already the 1.36 default.
- 00:25:57 → 00:33:11 — control plane **1.35** (eks.23). 00:33:14 → 00:39:56 nodes **1.35.8** (1b). kube-proxy → v1.35.3-eksbuild.29, coredns → v1.13.2-eksbuild.31. Health 200/200, `/data` intact.
- 00:41:36 → 00:48:49 — control plane **1.36** (eks.13). 00:48:53 → 00:55:35 nodes **1.36.4** (AMI 1.36.4-20260917, 1b). kube-proxy → v1.36.0-eksbuild.25, coredns → v1.14.3-eksbuild.23. Health 200/200, `/data` intact.
- 00:58 — final smoke test: EA upload (161 KB windstream file) 10 s, dry run 1 s, test session deleted (200). All 6 add-ons ACTIVE; LBC + ExternalDNS 0 errors; CloudWatch receiving app logs.

## Outcome
Control plane 1.31.14 → **1.36 (eks.13)**; nodes 1.30 → **1.36.4** on single-AZ `vm-group-1b`. Add-ons: kube-proxy v1.36.0-eksbuild.25, coredns v1.14.3-eksbuild.23, vpc-cni v1.22.4-eksbuild.3, EBS CSI v1.66.0-eksbuild.1, metrics-server v0.9.0-eksbuild.11, CloudWatch v6.7.0-eksbuild.1. LBC v2.17.1 (chart 1.17.1), ExternalDNS v0.22.0 (chart 1.22.0). Snapshot snap-04ad07ff951517c98 retained. App outages: 6 node rolls, each a Recreate restart of ~1–2 min (backend back within the rollout wait every time); total well under 15 min across ~2 h.

## Findings
- **Backend ALB target group has had 0 healthy targets for ≥7 days** (pre-existing, not upgrade-caused): health check path `/` returns 404 on the backend (`/healthz` is 200). The ALB fails open (all targets unhealthy → route to all), which is why the app works. Follow-up: set `alb.ingress.kubernetes.io/healthcheck-path: /healthz` for the backend ingress.
- SSO sessions expire ~1 h into a run on this host; wait loops must treat an auth error as "unknown", not "done" (wait-update.sh's loop broke on the empty status).
- `aws eks wait cluster-active` returns immediately right after `update-cluster-version` (status not yet UPDATING) — wait on `describe-update --update-id` instead (`wait-update.sh`).
- `helm upgrade --reuse-values` across chart versions keeps the old default image tag under helm v4 — pass the user values file instead.
- EKS Upgrade Insights refresh ~daily; there is no CLI to force a refresh, so skew WARNINGs lag real fixes by up to a day. Verified actual kubelet/kube-proxy versions instead.
- ExternalDNS 0.22 reports obsolete legacy `cname-*` TXT records (fortiflex-marketplace, -api, fortiflex, vm-test) — safe to clean up later with its `aws-cleanup-legacy-txt-records.py`.

## Deviations from plan
- coredns follows the EKS default per version (1.11.4 → 1.12.4 at 1.33 → 1.13.2 at 1.35 → 1.14.3 at 1.36) rather than jumping to 1.13.2 at 1.33.
- ExternalDNS went to 0.22.0 (latest) rather than the plan's example 0.19.0.
