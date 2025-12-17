# Quick Start: CI/CD Pipeline

A quick reference guide to get the production CI/CD pipeline up and running.

## ⚡ 5-Minute Setup

### Step 1: Configure GitHub Secrets

You need kubeconfig files for your Kubernetes clusters. For each environment:

```bash
# Generate base64-encoded kubeconfig
kubectl config view --minify --flatten | base64 -w 0
```

Add these secrets in GitHub → Settings → Secrets and variables → Actions:

| Secret Name | Value |
|-------------|-------|
| `DEV_KUBECONFIG` | Base64-encoded kubeconfig for dev cluster |
| `STAGING_KUBECONFIG` | Base64-encoded kubeconfig for staging cluster |
| `PROD_KUBECONFIG` | Base64-encoded kubeconfig for production cluster |

### Step 2: Create Service Accounts (Recommended)

For better security, create dedicated service accounts:

```bash
# For each environment (dev, staging, prod), run:
NAMESPACE="camel-k-dev"  # or camel-k-staging, camel-k-prod

# Create namespace
kubectl create namespace $NAMESPACE

# Create service account
kubectl create serviceaccount github-actions -n $NAMESPACE

# Create role with necessary permissions
kubectl create role camel-k-deployer \
  --verb=get,list,watch,create,update,patch,delete \
  --resource=integrations,integrationplatforms,integrationkits,pods,services,configmaps,deployments \
  -n $NAMESPACE

# Bind role to service account
kubectl create rolebinding github-actions-deployer \
  --role=camel-k-deployer \
  --serviceaccount=$NAMESPACE:github-actions \
  -n $NAMESPACE

# Generate long-lived token (for CI/CD)
kubectl create token github-actions -n $NAMESPACE --duration=87600h > token.txt

# Create kubeconfig file for this service account
cat > sa-kubeconfig.yaml << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
    server: $(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.server}')
  name: $(kubectl config view --raw -o jsonpath='{.clusters[0].name}')
contexts:
- context:
    cluster: $(kubectl config view --raw -o jsonpath='{.clusters[0].name}')
    user: github-actions
    namespace: $NAMESPACE
  name: github-actions
current-context: github-actions
users:
- name: github-actions
  user:
    token: $(cat token.txt)
EOF

# Base64 encode for GitHub secret
cat sa-kubeconfig.yaml | base64 -w 0

# Clean up
rm token.txt sa-kubeconfig.yaml
```

### Step 3: Set Up Branch Protection

Go to GitHub → Settings → Branches → Add rule

**For `main` branch:**
- Branch name pattern: `main`
- ✅ Require pull request reviews before merging (2 reviewers)
- ✅ Require status checks to pass
- ✅ Require branches to be up to date
- ✅ Include administrators

**For `staging` branch:**
- Branch name pattern: `staging`
- ✅ Require pull request reviews before merging (1 reviewer)
- ✅ Require status checks to pass

**For `develop` branch:**
- Branch name pattern: `develop`
- ✅ Require status checks to pass

### Step 4: Create Initial Branches

```bash
# Clone repository
git clone <your-repo-url>
cd kamel-poc

# Create and push develop branch
git checkout -b develop
git push origin develop

# Create and push staging branch
git checkout -b staging
git push origin staging

# Main branch should already exist
```

### Step 5: Test the Pipeline

**Test CI Pipeline:**
```bash
# Create a test branch
git checkout -b test/ci-pipeline

# Make a small change
echo "# Test" >> test.md
git add test.md
git commit -m "test: verify CI pipeline"

# Push and create PR
git push origin test/ci-pipeline
```

Go to GitHub and create a PR targeting `develop`. The CI pipeline should run automatically.

**Test Dev Deployment:**
```bash
# Merge the PR to develop branch
# This will automatically trigger deployment to DEV environment

# Check deployment in GitHub Actions tab
# Monitor logs and verify deployment success
```

**Test Staging Deployment:**
```bash
# Create PR from develop to staging
git checkout staging
git pull origin staging
git merge develop
git push origin staging

# Or create PR on GitHub: develop → staging
# After merge, deployment to STAGING will trigger
```

**Test Production Deployment:**
```bash
# Create PR from staging to main (requires 2 approvals)
git checkout main
git pull origin main
git merge staging
git push origin main

# Or create PR on GitHub: staging → main
# After merge and approvals, deployment to PRODUCTION will trigger
```

---

## 📋 Daily Workflow

### For New Features

```bash
# 1. Start from develop
git checkout develop
git pull origin develop

# 2. Create feature branch
git checkout -b feature/my-feature

# 3. Make changes
# ... edit files ...
git add .
git commit -m "feat: add my feature"

# 4. Push and create PR
git push origin feature/my-feature
# Create PR on GitHub: feature/my-feature → develop

# 5. After approval and CI passes
# Merge PR → Automatically deploys to DEV
```

### For Releases

```bash
# 1. Test in DEV (automatic after merge to develop)
# ... verify functionality ...

# 2. Promote to STAGING
# Create PR: develop → staging
# After merge: Automatically deploys to STAGING

# 3. Test in STAGING
# ... run smoke tests, UAT ...

# 4. Promote to PRODUCTION (requires 2 approvals)
# Create PR: staging → main
# After merge: Automatically deploys to PRODUCTION
```

---

## 🎯 What Each Environment Does

### Development (develop branch → camel-k-dev namespace)
- **Purpose**: Fast iteration and testing
- **Logging**: DEBUG level
- **Monitoring**: Basic health checks
- **Auto-deploy**: On every merge to develop
- **Resource limits**: Relaxed for testing

### Staging (staging branch → camel-k-staging namespace)
- **Purpose**: Pre-production validation
- **Logging**: INFO level (JSON format)
- **Monitoring**: Prometheus metrics enabled
- **Auto-deploy**: On every merge to staging
- **Tests**: Smoke tests included
- **Configuration**: Production-like

### Production (main branch → camel-k-prod namespace)
- **Purpose**: Live production environment
- **Logging**: INFO level (JSON format)
- **Monitoring**: Full Prometheus + health checks
- **Auto-deploy**: On every merge to main
- **Tests**: Health checks + log validation
- **Backup**: Automatic before deployment
- **Rollback**: Backup artifacts stored
- **Versioning**: Git tags created

---

## 🔍 Monitoring Deployments

### GitHub Actions Dashboard
```
Repository → Actions tab

View:
- Active workflow runs
- Deployment history
- Logs and artifacts
- Success/failure status
```

### Kubernetes Cluster
```bash
# Check deployment status
kubectl get integration -n camel-k-dev      # Dev
kubectl get integration -n camel-k-staging  # Staging
kubectl get integration -n camel-k-prod     # Production

# View logs
kubectl logs -l camel.apache.org/integration=consumer-dev -n camel-k-dev
kubectl logs -l camel.apache.org/integration=consumer-staging -n camel-k-staging
kubectl logs -l camel.apache.org/integration=consumer-prod -n camel-k-prod

# Check pods
kubectl get pods -n camel-k-dev
kubectl get pods -n camel-k-staging
kubectl get pods -n camel-k-prod
```

---

## 🚨 Emergency Procedures

### Manual Deployment Trigger

If you need to deploy outside the normal flow:

1. Go to **Actions** tab in GitHub
2. Select appropriate deployment workflow
3. Click **Run workflow**
4. Choose branch and enter reason
5. Click **Run workflow**

### Rollback Production Deployment

**Option 1: Using Backup Artifact**
1. Go to failed deployment run in Actions
2. Download backup artifact
3. Extract and apply:
   ```bash
   unzip prod-backup-*.zip
   kubectl apply -f backup-*/integration.yaml -n camel-k-prod
   ```

**Option 2: Using Git**
```bash
# Find last working version
git log --oneline
git tag -l "v*"

# Checkout previous version
git checkout <previous-commit>

# Manually trigger production deployment
# Go to Actions → Deploy to Production → Run workflow
```

**Option 3: Quick kubectl rollback**
```bash
# Delete current deployment
kubectl delete integration consumer-prod -n camel-k-prod

# Revert code in Git
git checkout <previous-working-commit>

# Redeploy using kamel CLI
kamel run consumer.java \
  --name consumer-prod \
  --namespace camel-k-prod \
  --property app.environment=production
```

---

## 📚 Additional Resources

| Document | Purpose |
|----------|---------|
| [README.md](./README.md) | Project overview and quick start |
| [DOCUMENTATION.md](./DOCUMENTATION.md) | Detailed technical documentation |
| [SDLC-PIPELINE.md](./SDLC-PIPELINE.md) | Complete pipeline documentation |
| [.github/workflows/README.md](./.github/workflows/README.md) | Workflow details |

---

## ✅ Checklist: First Time Setup

- [ ] Add kubeconfig secrets to GitHub (DEV, STAGING, PROD)
- [ ] Create branch protection rules
- [ ] Create `develop` and `staging` branches
- [ ] Test CI pipeline with a test PR
- [ ] Verify dev deployment works
- [ ] Verify staging deployment works
- [ ] Test production deployment (with proper approvals)
- [ ] Set up monitoring/alerting (recommended)
- [ ] Document any custom configurations
- [ ] Train team on new workflow

---

## 💡 Pro Tips

1. **Test locally first**: Use `kamel run --dev` before pushing
2. **Small PRs**: Keep changes focused and reviewable
3. **Monitor deployments**: Watch logs during deployment
4. **Use manual trigger sparingly**: Only for emergencies
5. **Tag releases**: Git tags are automatically created for production
6. **Review security scans**: Address findings before merging
7. **Keep secrets rotated**: Update kubeconfigs every 90 days
8. **Monitor resource usage**: Adjust limits as needed

---

**Need help?** See the full [SDLC-PIPELINE.md](./SDLC-PIPELINE.md) documentation.
