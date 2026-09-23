# Reference — Vending Machine POC

> Read this when navigating unfamiliar code, running a less-common command, or setting an env var.
> Linked from [CLAUDE.md](../../CLAUDE.md).

## Key File Map

```
Makefile                          — EKS lifecycle orchestration (make up/down/deploy-*)
.cluster.env                      — Runtime state (VPC, IAM ARNs) — auto-generated, gitignored
.gitmodules                       — Submodule ref: apps/fortiflex-marketplace
compose.yaml                      — Local dev stack (FortiFlex + DynamoDB Local)
compose.fortiflex-marketplace.yaml — Compose override for marketplace submodule
verify-fortiflex-deployment.sh    — Post-deploy health check script
apps/
  charts/shared/                  — Single Helm chart used by all services
  fortiflex-marketplace/          — Git submodule → fortigate-marketplace repo
  vm-poc-backend-fortiflex/       — FortiFlex API backend (FastAPI + DynamoDB)
  vm-poc-backend-fortiflex-marketplace/ — Marketplace backend Helm values
  vm-poc-frontend-fortiflex/      — FortiFlex frontend (Nginx)
  vm-poc-frontend-fortiflex-marketplace/ — Marketplace frontend Helm values
  vm-poc-backend-greeting/        — Sample greeting microservice
  vm-poc-backend-math/            — Sample math microservice
  vm-poc-backend-echo/            — Sample echo service (FastAPI)
  vm-poc-frontend/                — Sample frontend
  FORTIFLEX_MARKETPLACE_INTEGRATION.md — Submodule integration guide
  FORTIFLEX_MARKETPLACE_WORKFLOW.md    — Marketplace dev workflow
arch/
  event-poc-cluster.yaml          — eksctl cluster spec
  sa-roles-cft.yml                — CloudFormation for ALB/ExternalDNS IRSA roles
  sa.yml                          — Service account manifests (patched at deploy)
  registry/                       — Terraform: auto-discovers services, provisions ECR repos
  dynamodb/                       — Terraform: shared products table + reader IRSA role
  iam/                            — Cross-account access policies
modules/
  microservice-ecr/               — Reusable Terraform module for ECR repos
dynamodb/
  products_seed.json              — Product catalog seed data
  seed_products.py                — Seed script (supports local + AWS)
crds/
  crds.yaml                       — ALB Controller CRDs
.github/
  workflows/build-deploy.yml      — CI: Terraform reconcile → build matrix → ECR push
  copilot-instructions.md         — AI agent context (comprehensive)
```

## Build & Run Commands

```bash
# Full EKS cluster bring-up (cluster + controllers + DynamoDB)
make up

# Deploy sample apps
make deploy-app-helm-charts

# Deploy FortiFlex POC (needs TABLE + ROLE)
make deploy-fortiflex-poc TABLE=vm-poc-products ROLE=arn:aws:iam::<acct>:role/vm-poc-products-reader

# Deploy FortiFlex Marketplace (submodule-based)
make deploy-fortiflex-marketplace

# Tear down everything
make down

# Local dev (Docker Compose)
docker compose up --build                          # FortiFlex stack + DynamoDB Local
docker compose -f compose.yaml -f compose.fortiflex-marketplace.yaml up --build  # + marketplace

# Seed local DynamoDB
python dynamodb/seed_products.py --table-name vm-poc-products-local --region us-east-1 --endpoint-url http://localhost:8000

# Update submodule to latest
cd apps/fortiflex-marketplace && git pull origin main
```

## Environment Variables

```bash
# Cluster config (Makefile defaults)
AWS_ACCT=228122752878
AWS_DEFAULT_REGION=us-east-1
AWS_PROFILE=our-eks
cluster_name=vending-machine-poc
route53_domain=fortinetcloudcse.com

# Generated into .cluster.env by Makefile targets
VPC_ID=                    # make get-cluster-info
SUBNET_ID_1=               # make get-cluster-info
SUBNET_ID_2=               # make get-cluster-info
SG_ID=                     # make get-cluster-info
ALBIngressRoleArn=         # make extract-iam-roles
ExternalDNSRoute53RoleArn= # make extract-iam-roles
PRODUCTS_TABLE_NAME=       # make provision-dynamodb
DYNAMODB_READER_ROLE_ARN=  # make provision-dynamodb

# Backend services (compose.yaml)
SESSION_SECRET=            # Session middleware secret
DEBUG=true                 # Enable debug logging
```
