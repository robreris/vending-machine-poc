# Vending Machine POC - AI Coding Agent Instructions

## Project Overview
Account vending machine POC/MVP: microservices architecture deployed to AWS EKS with automated infrastructure provisioning, shared product catalog (DynamoDB), and CI/CD via GitHub Actions.

## Architecture Essentials

### Component Structure
- **`apps/`**: Microservices organized as `vm-poc-{backend|frontend}-{name}/` folders
  - Each service: `app/` (code + Dockerfile), `values.yaml` (Helm config), optional `terraform/` (service-owned AWS resources)
  - Frontend services: Nginx-based static apps pointing to backend APIs
  - Backend services: FastAPI apps with session middleware, CORS, and optional DynamoDB access
- **`apps/charts/shared/`**: Single Helm chart consumed by all services via `-f apps/<service>/values.yaml`
- **`arch/`**: Infrastructure-as-code (EKS cluster config, CloudFormation IAM roles, Terraform ECR/DynamoDB provisioning)
- **`modules/microservice-ecr/`**: Reusable Terraform module for ECR repository creation

### Service Discovery & Communication
Services communicate over Kubernetes DNS using Helm release names (from `values.yaml` `name` field):
```yaml
# Frontend calling backend
env:
  FORTIFLEX_BACKEND_URL: "http://vm-poc-backend-fortiflex:5000"
```

### Shared Product Catalog (DynamoDB)
- **Provisioning**: `make provision-dynamodb` → `arch/dynamodb/main.tf` creates table + IRSA role
- **Outputs exported to `.cluster.env`**: `PRODUCTS_TABLE_NAME`, `DYNAMODB_READER_ROLE_ARN`
- **IRSA binding**: Services annotate ServiceAccount with `eks.amazonaws.com/role-arn` in `values.yaml`
- **Seeding**: `python dynamodb/seed_products.py --table-name <name> --region <region>` (supports `--endpoint-url` for DynamoDB Local)

## Development Workflows

### Kubernetes Access & Authentication
**CRITICAL**: Deployments are in the `default` namespace, NOT `vm-apps`.

**AWS Authentication**:
1. **Profile**: Use `our-eks` profile for cluster access
2. **Re-authentication**: AWS SSO sessions expire after 8-12 hours
   ```bash
   # When you get "Unable to locate credentials" or "AccessDenied" errors
   export AWS_PROFILE=our-eks
   aws sso login
   ```
3. **Update kubeconfig**: Always refresh after re-authentication
   ```bash
   AWS_PROFILE=our-eks aws eks update-kubeconfig --name vending-machine-poc --region us-east-1
   ```

**Managing Deployments**:
```bash
# Restart a deployment (namespace: default, not vm-apps)
AWS_PROFILE=our-eks kubectl rollout restart deployment vm-poc-backend-fortiflex-marketplace -n default

# Check rollout status
AWS_PROFILE=our-eks kubectl rollout status deployment vm-poc-backend-fortiflex-marketplace -n default

# View pod logs
AWS_PROFILE=our-eks kubectl logs -n default -l app=vm-poc-backend-fortiflex-marketplace --tail=50

# Get pods
AWS_PROFILE=our-eks kubectl get pods -n default
```

### Full Stack Deployment (EKS)
```bash
# Bootstrap cluster, controllers, and DynamoDB
make up

# Deploy services via shared Helm chart
make deploy-app-helm-charts

# Teardown (includes DynamoDB cleanup)
make down
```

### Local Development (Docker Compose)
```bash
# Start reference stack (includes DynamoDB Local on :8000)
docker compose up --build

# Layer override for testing new service
docker compose -f compose.yaml -f compose.vm-poc-backend-echo.yaml up --build
```

### Adding a New Microservice

**Option 1: New service in this repo**
1. **Scaffold**: Create `apps/vm-poc-{type}-{name}/app/` with Dockerfile and source
2. **Configure Helm**: Add `values.yaml` with `name` (becomes ECR repo + k8s release), `containerPort`, `servicePort`, `env` vars
3. **Wire dependencies**: Set `env.BACKEND_URL` to `http://<other-service-name>:<port>` for inter-service calls
4. **Deploy**: CI auto-provisions ECR repo on next push (detects `values.yaml`), then `helm upgrade --install <name> ./apps/charts/shared -f apps/<name>/values.yaml`

**Option 2: External repo as Git submodule** (see `apps/FORTIFLEX_MARKETPLACE_INTEGRATION.md`)
1. **Add submodule**: `git submodule add -b <branch> <repo-url> apps/<submodule-name>`
2. **Create compose override**: Create `compose.<submodule-name>.yaml` with build contexts pointing to `./apps/<submodule-name>/{backend|frontend}`
3. **Pass build args**: Use `build.args` in compose file to inject environment-specific values (e.g., `VITE_BACKEND_HOST` for frontend builds)
4. **Update submodule**: `cd apps/<submodule-name> && git pull origin <branch>` to pull latest code from external repo
5. **CRITICAL**: **ALL CODE CHANGES** must be made in the original repo, committed, pushed, then pulled into the submodule. **NEVER edit code directly in `apps/<submodule-name>/`**
6. **CI/CD**: GitHub Actions auto-checks out submodules (`submodules: recursive`), builds from submodule directories

### CI/CD Automation (`.github/workflows/build-deploy.yml`)
- **Triggers**: Push to `main` (or manual `workflow_dispatch`)
- **Reconciliation**: Runs `arch/registry` Terraform → discovers all `apps/*/values.yaml`, creates missing ECR repos
- **Build matrix**: Extracts `repository_urls` + `repo_to_service` maps from Terraform outputs
- **Image build**: Each service image built from `apps/<service>/app/` and pushed to matching ECR repo with `:latest` tag

## Project-Specific Conventions

### `.cluster.env` State File Pattern
Makefile targets export runtime values (VPC, subnets, IAM role ARNs) to `.cluster.env` for reuse across targets:
```bash
# Targets write
echo "VPC_ID=$$VPC_ID" > .cluster.env

# Subsequent targets read
[[ -f .cluster.env ]] && source .cluster.env || true
```

### Terraform Service Discovery (`arch/registry/main.tf`)
Auto-discovers services by scanning `apps/*/values.yaml` files (excludes `charts/`):
```hcl
locals {
  value_files = fileset("${path.root}/../../apps", "*/values.yaml")
  services = [
    for rel in local.value_files : {
      service   = split("/", rel)[0]
      repo_name = yamldecode(file(".../${rel}")).name  # <- Helm release name = ECR repo name
    }
    if split("/", rel)[0] != "charts"
  ]
}
```

### IRSA (IAM Roles for Service Accounts) Pattern
1. **Create role**: Terraform module defines trust policy with OIDC provider + service account subject
2. **Export ARN**: Terraform outputs role ARN → Makefile appends to `.cluster.env`
3. **Annotate in Helm**: `serviceAccount.annotations."eks.amazonaws.com/role-arn"` in `values.yaml` (or `--set` during deploy)
4. **Pod inherits**: AWS SDK auto-discovers credentials via projected token volume

### sed-based Config Patching (`configure-sa` target)
Runtime values (IAM role ARNs, namespaces) injected into `arch/sa.yml` via sed before `kubectl apply`:
```bash
sed -i "/name: aws-alb-ingress-controller/,/eks.amazonaws.com\\/role-arn:/ s#...#\\1 $$ALBIngressRoleArn#" arch/sa.yml
```

### Helm Retry Pattern (Load Balancer Controller)
Critical controllers use exponential backoff with max attempts to handle transient failures:
```bash
MAX_ATTEMPTS=8
DELAY=5
while :; do
  if helm upgrade --install ...; then break; fi
  # Exponential backoff up to 60s
  DELAY=$$(( DELAY < 60 ? DELAY * 2 : 60 ))
done
```

## Integration Points

### AWS Controllers
- **ALB Controller**: Ingress → ALB creation, requires VPC ID + cluster security group (extracted by `get-cluster-info`)
- **ExternalDNS**: Watches Ingress resources, updates Route 53 when `ingress.enabled=true` + `ingress.host` set in `values.yaml`
- **Service Account binding**: Both use IRSA roles provisioned by `arch/sa-roles-cft.yml` CloudFormation stack

### Helm Release Pattern
All services share `apps/charts/shared/templates/` (deployment, service, ingress). Values override per service:
```yaml
# Shared defaults (apps/charts/shared/values.yaml)
ECRregistry: 228122752878.dkr.ecr.us-east-1.amazonaws.com
replicas: 1

# Service-specific (apps/vm-poc-backend-fortiflex/values.yaml)
name: vm-poc-backend-fortiflex
containerPort: 5000
env:
  PRODUCTS_TABLE_NAME: ""  # Populated via --set during deploy
```

### DynamoDB Local (Compose)
Override `AWS_ENDPOINT_URL_DYNAMODB` to `http://dynamodb:8000` in `compose.yaml` for local dev. Seed with:
```bash
python dynamodb/seed_products.py --table-name vm-poc-products-local --region us-east-1 --endpoint-url http://localhost:8000
```

## Common Pitfalls

1. **Wrong namespace**: Deployments are in `default` namespace, NOT `vm-apps` (use `-n default` for kubectl commands)
2. **AWS SSO expiration**: Credentials expire after 8-12 hours, causing "AccessDenied" or "Unable to locate credentials" errors - re-run `aws sso login` with `our-eks` profile
3. **Stale kubeconfig**: After re-authenticating, always run `AWS_PROFILE=our-eks aws eks update-kubeconfig --name vending-machine-poc --region us-east-1`
4. **Missing `.cluster.env`**: If targets fail with undefined VPC/role variables, run `make get-cluster-info` or `make extract-iam-roles` to regenerate state file
5. **Service name mismatch**: `values.yaml` `name` field MUST match ECR repo name (Terraform creates repos from this value)
6. **IRSA requires OIDC**: Run `make iam-oidc` before provisioning DynamoDB or deploying services that need AWS API access
7. **Helm install order**: Deploy controllers (`make controllers`) before deploying apps with Ingress resources
8. **CloudFormation stack persistence**: `make down` attempts to delete `eks-addon-roles` stack, but manual cleanup may be needed if stack drift occurs
9. **Service account annotations**: For DynamoDB access, `serviceAccount.create=true` AND `annotations."eks.amazonaws.com/role-arn"` must both be set (see `vm-poc-backend-fortiflex/values.yaml`)
10. **Submodule not initialized**: If builds fail with missing source files, run `git submodule update --init --recursive`
11. **Stale submodule reference**: After updating code in external repo, run `cd apps/<submodule> && git pull origin <branch>` in vending-machine-poc to pull latest changes
12. **NEVER edit submodule code directly**: All code changes MUST be made in the original repo (e.g., `fortigate-marketplace`), committed, pushed, then pulled into `apps/<submodule>/`. Docker builds use the submodule directory directly, NOT symlinks.
13. **Build args for multi-environment**: When integrating external frontends, pass build args (e.g., `VITE_BACKEND_HOST`) via `compose.yaml` `build.args` to inject environment-specific URLs at build time

## Key Files Reference

- **Orchestration**: `Makefile` - 247 lines of cluster lifecycle targets (use `make help` for full list)
- **Cluster config**: `arch/event-poc-cluster.yaml` - eksctl declarative cluster spec
- **IAM roles**: `arch/sa-roles-cft.yml` - CloudFormation template for ALB/ExternalDNS IRSA roles
- **ECR provisioning**: `arch/registry/main.tf` - auto-discovers services, outputs repo URLs
- **DynamoDB + IRSA**: `arch/dynamodb/main.tf` - table + reader role with OIDC trust policy
- **CI matrix build**: `.github/workflows/build-deploy.yml` - Terraform → build matrix → parallel ECR pushes
- **Product catalog seed**: `dynamodb/products_seed.json` + `seed_products.py` - initial catalog data

## Configuration Defaults
Override via Makefile vars or `.cluster.env`:
- **AWS_ACCT**: `228122752878`
- **AWS_DEFAULT_REGION**: `us-east-1`
- **AWS_PROFILE**: `our-eks` (required for kubectl/EKS access)
- **cluster_name**: `vending-machine-poc`
- **app_namespace**: `default` (NOT `vm-apps` - this is critical for kubectl commands)
- **route53_domain**: `fortinetcloudcse.com`
