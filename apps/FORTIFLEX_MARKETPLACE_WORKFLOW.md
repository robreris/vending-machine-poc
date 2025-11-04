# FortiFlex Marketplace Development Workflow

## ⚠️ CRITICAL RULE: Never Edit Code in the Submodule!

**All application code changes MUST be made in the original repository:**
```bash
cd /home/ubuntu/pythonProjects/fortigate-marketplace
```

**DO NOT edit anything under:**
```bash
/home/ubuntu/pythonProjects/vending-machine-poc/apps/fortiflex-marketplace/
```

This is a Git submodule - changes made here won't sync back to the original repo!

---

## Daily Development

### Work on the app code (in fortigate-marketplace repo)
```bash
cd /home/ubuntu/pythonProjects/fortigate-marketplace

# Make changes to backend or frontend
vim backend/app/routes/some_feature.py
vim frontend/src/components/SomeComponent.tsx

# Test locally in fortigate-marketplace
cd backend && uvicorn app.main:app --reload
# or
cd frontend && npm run dev

# Commit and push to fortigate-marketplace repo
git add .
git commit -m "Add new feature"
git push origin jkopkoEdits
```

### Deploy to vending-machine-poc infrastructure

```bash
cd /home/ubuntu/pythonProjects/vending-machine-poc

# Update submodule to latest code
git submodule update --remote apps/fortiflex-marketplace

# Test with Docker Compose locally
docker compose -f compose.fortiflex-marketplace.yaml up --build

# Commit the submodule reference update
git add apps/fortiflex-marketplace
git commit -m "Update fortiflex-marketplace to latest"
git push origin main
```

**On push to main**, GitHub Actions will:
1. Check out the repo with submodules
2. Discover the two new services via their `values.yaml` files
3. Create ECR repos: `vm-poc-backend-fortiflex-marketplace` and `vm-poc-frontend-fortiflex-marketplace`
4. Build Docker images from `apps/fortiflex-marketplace/{backend,frontend}/`
5. Push to ECR with `:latest` tag

### Deploy to EKS

```bash
# SSH to environment with kubectl/helm access
# Deploy backend
helm upgrade --install vm-poc-backend-fortiflex-marketplace \
  ./apps/charts/shared \
  -f apps/vm-poc-backend-fortiflex-marketplace/values.yaml \
  -n vm-apps

# Deploy frontend
helm upgrade --install vm-poc-frontend-fortiflex-marketplace \
  ./apps/charts/shared \
  -f apps/vm-poc-frontend-fortiflex-marketplace/values.yaml \
  -n vm-apps
```

## Making Infrastructure Changes

### Update Helm values (in vending-machine-poc repo)

```bash
cd /home/ubuntu/pythonProjects/vending-machine-poc

# Modify deployment config
vim apps/vm-poc-backend-fortiflex-marketplace/values.yaml
# Examples:
# - Change replicas
# - Add environment variables
# - Enable ingress
# - Configure IRSA annotations for DynamoDB access

git add apps/vm-poc-backend-fortiflex-marketplace/values.yaml
git commit -m "Configure marketplace backend for production"
git push origin main
```

## Troubleshooting

### Submodule shows "modified content"
```bash
cd apps/fortiflex-marketplace
git status  # See what changed
git checkout jkopkoEdits  # Reset to tracked branch
```

### Need to switch to a different branch
```bash
cd apps/fortiflex-marketplace
git fetch origin
git checkout feature-branch
cd ../..
git add apps/fortiflex-marketplace
git commit -m "Point to feature-branch"
```

### CI build fails on submodule checkout
Ensure `.gitmodules` and the submodule commit are both pushed to the repo. GitHub Actions uses:
```yaml
- uses: actions/checkout@v4
  with:
    submodules: recursive  # This is automatic in the workflow
```
