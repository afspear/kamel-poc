# GitHub Actions Workflows

This directory contains the CI/CD pipeline workflows for the Camel K POC project.

## Workflows Overview

### 1. CI Pipeline (`ci.yml`)
**Trigger**: Pull requests and pushes to main branches

**Purpose**: Continuous Integration - validates code quality and functionality

**Jobs**:
- Lint and validate code
- Security scanning with Trivy
- Build and test integration
- Verify Camel K deployment

**Duration**: ~5-10 minutes

---

### 2. Deploy to Development (`deploy-dev.yml`)
**Trigger**: Commits to `develop` branch

**Purpose**: Continuous Deployment to development environment

**Environment**: `camel-k-dev` namespace

**Features**:
- Debug logging enabled
- Fast iteration cycle
- Automatic deployment on merge
- Deployment metadata storage

**Duration**: ~3-5 minutes

---

### 3. Deploy to Staging (`deploy-staging.yml`)
**Trigger**: Commits to `staging` branch

**Purpose**: Pre-production testing and validation

**Environment**: `camel-k-staging` namespace

**Features**:
- Production-like configuration
- Smoke tests
- Prometheus metrics enabled
- Log validation

**Duration**: ~5-7 minutes

---

### 4. Deploy to Production (`deploy-prod.yml`)
**Trigger**: Commits to `main` branch

**Purpose**: Production deployment with validation and rollback capability

**Environment**: `camel-k-prod` namespace

**Features**:
- Automatic backup before deployment
- Health checks and validation
- Resource limits enforced
- Git tag creation
- Rollback support

**Duration**: ~7-10 minutes

---

## Workflow Execution Flow

```
Feature Branch
      ↓
   [PR Created]
      ↓
   [CI Pipeline] ← Lint, Security Scan, Build & Test
      ↓
  [Code Review]
      ↓
[Merge to develop]
      ↓
[Deploy to DEV] ← Automatic deployment
      ↓
   [Testing]
      ↓
[Merge to staging]
      ↓
[Deploy to STAGING] ← Smoke tests
      ↓
   [UAT/QA]
      ↓
[Merge to main] ← Requires 2 approvals
      ↓
[Deploy to PROD] ← Health checks, backup, rollback ready
```

---

## Required Secrets

Configure in GitHub Settings → Secrets and variables → Actions:

| Secret Name | Description | Format |
|-------------|-------------|--------|
| `DEV_KUBECONFIG` | Kubeconfig for dev cluster | Base64-encoded |
| `STAGING_KUBECONFIG` | Kubeconfig for staging cluster | Base64-encoded |
| `PROD_KUBECONFIG` | Kubeconfig for production cluster | Base64-encoded |

### Creating Kubeconfig Secrets

```bash
# Generate base64-encoded kubeconfig
kubectl config view --minify --flatten | base64 -w 0

# Add to GitHub Secrets with appropriate name
```

---

## Manual Workflow Trigger

All workflows support manual triggering:

1. Go to **Actions** tab in GitHub
2. Select the workflow you want to run
3. Click **Run workflow** button
4. Choose the branch
5. (For deployment workflows) Enter reason for deployment
6. Click **Run workflow**

---

## Monitoring Workflows

### View Workflow Runs
- Navigate to **Actions** tab
- Select specific workflow from left sidebar
- View run history, logs, and artifacts

### Download Artifacts
- Open completed workflow run
- Scroll to **Artifacts** section
- Download deployment info or backup files

### Check Workflow Status
- Workflow status badges available
- View in pull requests
- Monitor in Actions dashboard

---

## Troubleshooting

### Common Issues

**1. Workflow fails with authentication error**
- Verify kubeconfig secret is correctly set
- Check service account permissions
- Ensure cluster is accessible

**2. Integration deployment fails**
- Check Camel K operator logs
- Verify integration platform configuration
- Review build logs in integration kit

**3. Timeout errors**
- Increase timeout values in workflow
- Check cluster resources
- Verify network connectivity

**4. Security scan failures**
- Review Trivy scan results
- Update vulnerable dependencies
- Add exceptions if false positives

---

## Best Practices

1. **Always test locally** before creating PR
2. **Monitor CI checks** on pull requests
3. **Review deployment logs** after merging
4. **Use manual trigger** only for emergencies
5. **Keep workflows up to date** with repository changes
6. **Document workflow changes** in commit messages

---

## Additional Resources

- **Pipeline Documentation**: [SDLC-PIPELINE.md](../SDLC-PIPELINE.md)
- **GitHub Actions Docs**: https://docs.github.com/en/actions
- **Camel K Documentation**: https://camel.apache.org/camel-k/

---

*For complete pipeline documentation, see [SDLC-PIPELINE.md](../SDLC-PIPELINE.md)*
