# FortiFlex Marketplace Integration - Setup Complete ✓

## What Was Done

### 1. Added fortigate-marketplace as a Git Submodule
```bash
# Added to vending-machine-poc/apps/
apps/fortiflex-marketplace/  # → cloudcse-fortiflex-marketplace repo (jkopkoEdits branch)
```

### 2. Created Service Wrappers
Two new services that will be discovered by Terraform and CI/CD:

**Backend:**
- `apps/vm-poc-backend-fortiflex-marketplace/`
  - `values.yaml` - Helm configuration
  - `app/` - Symlink → `../fortiflex-marketplace/backend`

**Frontend:**
- `apps/vm-poc-frontend-fortiflex-marketplace/`
  - `values.yaml` - Helm configuration  
  - `app/` - Symlink → `../fortiflex-marketplace/frontend`

### 3. Updated CI/CD Workflow
Modified `.github/workflows/build-deploy.yml` to check out submodules:
```yaml
- uses: actions/checkout@v4
  with:
    submodules: recursive
```

### 4. Created Documentation
- `apps/FORTIFLEX_MARKETPLACE_INTEGRATION.md` - Architecture overview
- `apps/FORTIFLEX_MARKETPLACE_WORKFLOW.md` - Daily development workflow
- `compose.fortiflex-marketplace.yaml` - Local testing with Docker Compose
- Updated `.github/copilot-instructions.md` - Added submodule pattern and pitfalls

## How It Works

### Development Workflow
1. **Edit code** in `/home/ubuntu/pythonProjects/fortigate-marketplace`
2. **Commit & push** to cloudcse-fortiflex-marketplace repo
3. **Update submodule** in vending-machine-poc: `git submodule update --remote`
4. **Push to trigger CI/CD** - builds and pushes to ECR automatically

### What CI/CD Does
1. Checks out vending-machine-poc with submodules
2. Terraform discovers the two new `values.yaml` files
3. Creates ECR repos: `vm-poc-backend-fortiflex-marketplace` and `vm-poc-frontend-fortiflex-marketplace`
4. Builds images from `apps/fortiflex-marketplace/{backend,frontend}/`
5. Pushes to ECR with `:latest` tag

### Deployment
```bash
helm upgrade --install vm-poc-backend-fortiflex-marketplace \
  ./apps/charts/shared \
  -f apps/vm-poc-backend-fortiflex-marketplace/values.yaml \
  -n vm-apps
```

## Local Testing

```bash
cd /home/ubuntu/pythonProjects/vending-machine-poc

# Test just the marketplace apps
docker compose -f compose.fortiflex-marketplace.yaml up --build

# Backend: http://localhost:8001
# Frontend: http://localhost:8081
```

## Next Steps

### 1. Configure Environment Variables
Edit the `values.yaml` files to add any required environment variables:
```yaml
# apps/vm-poc-backend-fortiflex-marketplace/values.yaml
env:
  SESSION_SECRET: "change-in-production"
  PRODUCTS_TABLE_NAME: ""  # Set via --set during deploy
  AWS_REGION: us-east-1
  # Add other vars as needed
```

### 2. Enable Ingress (when ready for external access)
```yaml
# apps/vm-poc-frontend-fortiflex-marketplace/values.yaml
ingress:
  enabled: true
  host: fortiflex-marketplace.fortinetcloudcse.com
  certificateArn: arn:aws:acm:us-east-1:228122752878:certificate/your-cert-arn
```

### 3. Configure IRSA for DynamoDB Access (if needed)
```yaml
# apps/vm-poc-backend-fortiflex-marketplace/values.yaml
serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::228122752878:role/vm-poc-products-reader
```

### 4. Test the Build Locally
```bash
cd /home/ubuntu/pythonProjects/vending-machine-poc
docker compose -f compose.fortiflex-marketplace.yaml build

# Or build and run
docker compose -f compose.fortiflex-marketplace.yaml up --build
# Access: http://localhost:8001 (backend), http://localhost:8081 (frontend)
```

**SSL Configuration**:
- **Vending-machine/K8s**: No SSL at container level (termination at ALB/Ingress) ✅
- **Fortigate-marketplace dev**: SSL enabled via docker-compose CMD overrides + volume mounts
- Dockerfiles are production-ready by default (no SSL dependencies)

### 5. Commit and Push to Trigger CI/CD
```bash
git add .
git commit -m "Add fortigate-marketplace as submodule services"
git push origin main
```

## ⚠️ CRITICAL: Where to Edit Files

### DO NOT EDIT in vending-machine-poc submodule!
❌ **NEVER edit files under** `apps/fortiflex-marketplace/` 
   - This is a Git submodule - changes won't sync back to the original repo
   - You'll lose work and create confusing git states

### ✅ DO EDIT in the original repository!
**For application code changes:**
```bash
cd /home/ubuntu/pythonProjects/fortigate-marketplace
# Edit backend/frontend code here
git commit -am "Your changes"
git push origin main
```

**For infrastructure/deployment config:**
```bash
cd /home/ubuntu/pythonProjects/vending-machine-poc
# Edit values.yaml files, compose files, Makefiles here
```

## Important Notes

- **Source code lives in fortigate-marketplace** - edit there, not in the submodule
- **Infrastructure config lives in vending-machine-poc** - `values.yaml` files only
- **Submodule tracks a specific commit** - must update explicitly with `git submodule update --remote`
- **CI/CD automatically handles submodules** - no manual steps needed in GitHub Actions
- **Symlinks work with Docker** - Docker build follows symlinks to the actual Dockerfiles

## Troubleshooting

**Submodule shows as modified:**
```bash
cd apps/fortiflex-marketplace
git checkout jkopkoEdits
cd ../..
```

**Need latest code from marketplace:**
```bash
git submodule update --remote apps/fortiflex-marketplace
git add apps/fortiflex-marketplace
git commit -m "Update to latest marketplace code"
```

**Build fails locally:**
```bash
# Ensure submodule is initialized
git submodule init
git submodule update
```

## Documentation References
- Integration overview: `apps/FORTIFLEX_MARKETPLACE_INTEGRATION.md`
- Daily workflow: `apps/FORTIFLEX_MARKETPLACE_WORKFLOW.md`
- Vending-machine patterns: `.github/copilot-instructions.md`
