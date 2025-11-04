# FortiFlex Marketplace Integration

This directory integrates the fortigate-marketplace application as Git submodules, allowing the vending-machine-poc infrastructure to build and deploy the containers while maintaining the source code in its original repository.

## Structure

```
apps/
├── fortiflex-marketplace/              # Git submodule -> cloudcse-fortiflex-marketplace
│   ├── backend/
│   │   ├── app/
│   │   └── Dockerfile
│   └── frontend/
│       ├── src/
│       └── Dockerfile
├── vm-poc-backend-fortiflex-marketplace/
│   ├── values.yaml                     # Helm values for backend
│   └── app -> ../fortiflex-marketplace/backend  # Symlink
└── vm-poc-frontend-fortiflex-marketplace/
    ├── values.yaml                     # Helm values for frontend
    └── app -> ../fortiflex-marketplace/frontend # Symlink
```

## Developing the Code

**Work in the original repository:**
```bash
cd /home/ubuntu/pythonProjects/fortigate-marketplace
# Make your changes, commit, push as usual
git add .
git commit -m "Your changes"
git push origin jkopkoEdits
```

**Update the submodule in vending-machine-poc:**
```bash
cd /home/ubuntu/pythonProjects/vending-machine-poc
git submodule update --remote apps/fortiflex-marketplace
# Or pull specific commits:
cd apps/fortiflex-marketplace
git pull origin jkopkoEdits
cd ../..
```

**Commit the submodule reference update:**
```bash
git add apps/fortiflex-marketplace
git commit -m "Update fortiflex-marketplace submodule to latest"
git push
```

## Local Testing

**Test with Docker Compose:**
```bash
# Build and run just the marketplace services (production-ready, no SSL)
docker compose -f compose.fortiflex-marketplace.yaml up --build

# Or combine with the base stack
docker compose -f compose.yaml -f compose.fortiflex-marketplace.yaml up --build
```

Access:
- Backend: http://localhost:8001 (no SSL - production-ready)
- Frontend: http://localhost:8081 (no SSL - production-ready)

**Note**: SSL certificates are only used in the fortigate-marketplace repo for local development. In vending-machine-poc and production K8s deployments, SSL termination happens at the ALB/Ingress level, not at the container level.

## Deployment to EKS

The CI/CD workflow (`.github/workflows/build-deploy.yml`) will automatically:

1. **Discover services**: Terraform scans `apps/*/values.yaml` and finds the new marketplace services
2. **Create ECR repos**: `vm-poc-backend-fortiflex-marketplace` and `vm-poc-frontend-fortiflex-marketplace`
3. **Build images**: GitHub Actions checks out submodules automatically and builds from `apps/<service>/app/`
4. **Push to ECR**: Images tagged with `:latest`

**Deploy with Helm:**
```bash
# Backend
helm upgrade --install vm-poc-backend-fortiflex-marketplace \
  ./apps/charts/shared \
  -f apps/vm-poc-backend-fortiflex-marketplace/values.yaml \
  -n vm-apps

# Frontend
helm upgrade --install vm-poc-frontend-fortiflex-marketplace \
  ./apps/charts/shared \
  -f apps/vm-poc-frontend-fortiflex-marketplace/values.yaml \
  -n vm-apps
```

Or use the Makefile (if you add targets for these services):
```bash
make deploy-fortiflex-marketplace
```

## Updating Submodules for Others

When someone else clones the vending-machine-poc repo:

```bash
# Initial clone with submodules
git clone --recurse-submodules https://github.com/FortinetCloudCSE/cloudcse-fortiflex-marketplace.git

# Or if already cloned without submodules
git submodule init
git submodule update
```

## Configuration

Edit `values.yaml` files to configure:
- Environment variables
- Resource limits
- Ingress settings (domains, TLS certificates)
- Service account annotations (for IRSA/DynamoDB access)

The Dockerfiles and application code remain in the original `fortigate-marketplace` repository.
