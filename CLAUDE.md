# CLAUDE.md — Vending Machine POC

> Global preferences (planning workflow, code quality, operations): ~/.claude/CLAUDE.md

## On-Demand Docs

| Doc | Read it when... |
|-----|------------------|
| [docs/claude/reference.md](docs/claude/reference.md) | Navigating unfamiliar code, running a less-common `make`/`docker compose`/seed command, or setting an env var — full file map, command list, env vars |
| [docs/claude/gotchas.md](docs/claude/gotchas.md) | A Critical Rule below needs more context to act on safely — full incident detail behind each one-liner |

## Project in One Line

Account Vending Machine POC/MVP — microservices deployed to AWS EKS with Helm, shared DynamoDB product catalog, CI/CD via GitHub Actions, and the FortiFlex Marketplace integrated as a git submodule. Internal CloudCSE team infrastructure.

## Stack Quick Reference

| Layer | Tech | Port |
|-------|------|------|
| Orchestration | AWS EKS + eksctl + Helm shared chart | — |
| IaC | Terraform (ECR, DynamoDB) + CloudFormation (IAM/IRSA) | — |
| CI/CD | GitHub Actions (`build-deploy.yml`) | — |
| DNS/TLS | Route 53 + ACM + ExternalDNS + AWS ALB Controller | — |
| Catalog DB | DynamoDB (AWS) / DynamoDB Local (Compose) | 8000 |
| Backend services | FastAPI (Python) | 5000 |
| Frontend services | Nginx (static) / React+Vite | 80/8080 |
| Local dev | Docker Compose | varies |

## Critical Rules

- `.cluster.env` holds Makefile-generated runtime state (VPC ID, IAM ARNs, table names); other targets `source` it. Missing vars → `make get-cluster-info` or `make extract-iam-roles`.
- Namespace is `default`, NOT `vm-apps` — `vm-apps` exists but is unused for FortiFlex services.
- `apps/fortiflex-marketplace/` is a read-only git submodule of `fortigate-marketplace` — never edit in place; edit upstream, push, then `git pull` inside the submodule.
- `arch/registry/main.tf` auto-creates ECR repos from `apps/*/values.yaml`'s `name` field — it must match the desired repo name.
- IRSA pattern: Terraform creates the OIDC-trust role → ARN exported to `.cluster.env` → Helm `--set` annotates the ServiceAccount → pod auto-discovers creds.
- `make configure-sa` sed-patches `arch/sa.yml` with IAM role ARNs before `kubectl apply` — fragile if the YAML structure changes.
- ALB Controller install retries with exponential backoff (up to 8 attempts) for transient CRD/API failures.
- AWS SSO creds expire every 8–12h — re-auth with `AWS_PROFILE=our-eks aws sso login`, then refresh kubeconfig.
- Compose DynamoDB Local: use `dynamodb:8000` from other containers, `localhost:8000` from the host.
- Submodule frontends need `VITE_BACKEND_HOST` as a compose build arg to embed the right backend URL at build time.
- `kubectl rollout restart` does NOT apply `values.yaml`/Helm chart changes (only re-pulls the image under the existing spec) — use `helm upgrade` for any `values.yaml` change. See gotchas.md (caused a live 502 2026-09-01).
- `podSecurityContext.runAsNonRoot: true` needs an explicit numeric `runAsUser`/`runAsGroup` or the pod refuses to start (`CreateContainerConfigError`) — chart default is uid 1000; override per-app if the Dockerfile uses a different UID. See gotchas.md.
- `fortiflex-marketplace-fortiaigate` K8s Secret holds 4 keys now (not just `FORTIAIGATE_API_KEY`) — name is a kept misnomer. See gotchas.md.
- NetworkPolicy is chart-wide default-deny ingress; ALB + kubelet health-probe traffic is covered by a VPC-CIDR `ipBlock`, not a `podSelector`; egress is unrestricted by design. See gotchas.md.
- `VMPOCAccessRole`/cross-account Helm deploy access is a manual AWS CLI procedure in README.md, not IaC-managed. See gotchas.md.

## Common Tasks

**Add a new microservice:** Create `apps/vm-poc-{type}-{name}/app/` with Dockerfile + source, add `values.yaml` with unique `name`/ports/env. CI auto-provisions ECR on next push. Deploy with `helm upgrade --install <name> ./apps/charts/shared -f apps/<name>/values.yaml -n default`.

**Update submodule to latest:** `cd apps/fortiflex-marketplace && git pull origin main && cd ../.. && git add apps/fortiflex-marketplace && git commit -m "update submodule ref"`.

**Re-authenticate AWS:** `AWS_PROFILE=our-eks aws sso login` then `AWS_PROFILE=our-eks aws eks update-kubeconfig --name vending-machine-poc --region us-east-1`.

**Debug missing .cluster.env vars:** Run `make get-cluster-info` (VPC/subnets), `make extract-iam-roles` (IAM ARNs), or `make provision-dynamodb` (table/role).

**Test locally with Compose:** `docker compose up --build` starts the FortiFlex stack with DynamoDB Local. Seed with `python dynamodb/seed_products.py --table-name vm-poc-products-local --region us-east-1 --endpoint-url http://localhost:8000`.
