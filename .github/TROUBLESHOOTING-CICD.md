# CI/CD Pipeline Troubleshooting Guide

Quick reference for resolving common CI/CD pipeline issues.

## Table of Contents
- [GitHub Actions Issues](#github-actions-issues)
- [Kubernetes Authentication Issues](#kubernetes-authentication-issues)
- [Deployment Failures](#deployment-failures)
- [Integration Build Issues](#integration-build-issues)
- [Environment-Specific Issues](#environment-specific-issues)

---

## GitHub Actions Issues

### Issue: Workflow not triggering

**Symptoms:**
- PR created but CI workflow doesn't run
- Merge to branch but deployment doesn't start

**Possible Causes & Solutions:**

1. **Branch name mismatch**
   ```yaml
   # Check workflow trigger in .github/workflows/*.yml
   on:
     push:
       branches:
         - develop  # Must match exactly
   ```
   
   **Solution:** Ensure branch names match exactly (case-sensitive)

2. **Workflow file syntax error**
   ```bash
   # Validate YAML locally
   python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"
   ```
   
   **Solution:** Fix YAML syntax errors

3. **Workflow disabled**
   - Go to Actions tab → Select workflow → Check if enabled
   
   **Solution:** Enable workflow in GitHub UI

### Issue: "Secrets not found" error

**Symptoms:**
```
Error: Secret DEV_KUBECONFIG not found
```

**Solution:**
```bash
# 1. Verify secret exists
# GitHub → Settings → Secrets and variables → Actions

# 2. Ensure secret name matches exactly (case-sensitive)
# In workflow: ${{ secrets.DEV_KUBECONFIG }}
# In GitHub: Must be named "DEV_KUBECONFIG"

# 3. Re-create secret if needed
kubectl config view --minify --flatten | base64 -w 0
# Copy output and paste into GitHub Secret
```

### Issue: Permission denied errors

**Symptoms:**
```
Error: Resource not accessible by integration
error: You must be logged in to the server (Unauthorized)
```

**Solutions:**

1. **GitHub token permissions**
   ```yaml
   # Add to workflow if needed
   permissions:
     contents: write
     packages: write
     actions: read
   ```

2. **Kubernetes RBAC**
   ```bash
   # Verify service account has proper permissions
   kubectl auth can-i create integrations -n camel-k-dev --as=system:serviceaccount:camel-k-dev:github-actions
   
   # Should return "yes"
   ```

---

## Kubernetes Authentication Issues

### Issue: "Unable to connect to server"

**Symptoms:**
```
error: Unable to connect to the server: x509: certificate signed by unknown authority
error: The connection to the server localhost:8080 was refused
```

**Diagnosis:**
```bash
# Test kubeconfig locally
export KUBECONFIG=/path/to/kubeconfig
kubectl cluster-info
kubectl get nodes
```

**Solutions:**

1. **Regenerate kubeconfig**
   ```bash
   # Create fresh kubeconfig
   kubectl config view --minify --flatten > kubeconfig-new.yaml
   
   # Verify it works
   kubectl --kubeconfig=kubeconfig-new.yaml get nodes
   
   # Base64 encode
   cat kubeconfig-new.yaml | base64 -w 0
   
   # Update GitHub Secret
   ```

2. **Check certificate validity**
   ```bash
   # Extract certificate
   kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > ca.crt
   
   # Check expiry
   openssl x509 -in ca.crt -noout -dates
   ```

3. **Verify cluster endpoint**
   ```bash
   # Check server URL
   kubectl config view --raw -o jsonpath='{.clusters[0].cluster.server}'
   
   # Test connectivity
   curl -k $(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.server}')/healthz
   ```

### Issue: "Unauthorized" or "Forbidden" errors

**Symptoms:**
```
Error from server (Forbidden): integrations.camel.apache.org is forbidden
error: You must be logged in to the server (Unauthorized)
```

**Solutions:**

1. **Check service account token expiry**
   ```bash
   # Tokens created with --duration have expiry
   # Check when token was created and its duration
   
   # Create new token
   kubectl create token github-actions -n camel-k-dev --duration=87600h
   ```

2. **Verify RBAC permissions**
   ```bash
   # Check role exists
   kubectl get role camel-k-deployer -n camel-k-dev
   
   # Check role binding
   kubectl get rolebinding github-actions-deployer -n camel-k-dev
   
   # View role permissions
   kubectl describe role camel-k-deployer -n camel-k-dev
   ```

3. **Re-create service account setup**
   ```bash
   # See QUICK-START-CICD.md for complete setup
   kubectl create serviceaccount github-actions -n camel-k-dev
   kubectl create role camel-k-deployer --verb=get,list,watch,create,update,patch,delete --resource=integrations,integrationplatforms,integrationkits,pods,services,configmaps,deployments -n camel-k-dev
   kubectl create rolebinding github-actions-deployer --role=camel-k-deployer --serviceaccount=camel-k-dev:github-actions -n camel-k-dev
   ```

---

## Deployment Failures

### Issue: Camel K operator not installing

**Symptoms:**
```
error: unable to recognize "github.com/apache/camel-k/...": no matches for kind "Integration"
```

**Diagnosis:**
```bash
# Check if operator is running
kubectl get deployment camel-k-operator -n camel-k-dev
kubectl get pods -n camel-k-dev

# Check CRDs
kubectl get crd | grep camel
```

**Solutions:**

1. **Wait for operator readiness**
   ```bash
   # In workflow, ensure adequate wait time
   kubectl wait --for=condition=available --timeout=180s deployment/camel-k-operator -n camel-k-dev
   ```

2. **Check operator logs**
   ```bash
   kubectl logs -n camel-k-dev deployment/camel-k-operator --tail=50
   ```

3. **Reinstall operator**
   ```bash
   # Delete and reinstall
   kubectl delete namespace camel-k-dev
   kubectl create namespace camel-k-dev
   kubectl apply --server-side=true -k "github.com/apache/camel-k/install/overlays/kubernetes/descoped?ref=v2.8.0" -n camel-k-dev
   ```

### Issue: Integration stuck in "Building" phase

**Symptoms:**
```
NAME       PHASE      KIT
consumer   Building   kit-xxxxx
```

**Diagnosis:**
```bash
# Check integration status
kubectl describe integration consumer-dev -n camel-k-dev

# Check integration kit
kubectl get integrationkit -n camel-k-dev
kubectl describe integrationkit <kit-name> -n camel-k-dev

# Check builder pod logs
kubectl logs -l camel.apache.org/integration=consumer-dev -c builder -n camel-k-dev
```

**Solutions:**

1. **Network/registry issues**
   - Check internet connectivity from cluster
   - Verify registry configuration in IntegrationPlatform
   - Check if registry is accessible

2. **Resource constraints**
   ```bash
   # Check node resources
   kubectl top nodes
   kubectl describe nodes
   
   # Increase resources if needed
   ```

3. **Build timeout**
   ```yaml
   # In k8s/{env}/integration-platform.yaml
   spec:
     build:
       timeout: 20m  # Increase if needed
   ```

### Issue: Health checks failing

**Symptoms:**
```
Health check failed after deployment
Integration not reaching Ready state
```

**Diagnosis:**
```bash
# Check integration status
kubectl get integration consumer-prod -n camel-k-prod -o yaml

# Check pod status
kubectl get pods -l camel.apache.org/integration=consumer-prod -n camel-k-prod

# Check logs
kubectl logs -l camel.apache.org/integration=consumer-prod -n camel-k-prod --tail=100
```

**Solutions:**

1. **Increase health check timeout**
   ```yaml
   # In workflow
   kubectl wait --for=condition=Ready --timeout=300s integration/consumer-prod
   ```

2. **Check application logs for errors**
   ```bash
   kubectl logs -l camel.apache.org/integration=consumer-prod -n camel-k-prod | grep -i error
   ```

3. **Verify integration platform configuration**
   ```bash
   kubectl get integrationplatform -n camel-k-prod -o yaml
   ```

---

## Integration Build Issues

### Issue: Maven dependency resolution failures

**Symptoms:**
```
Could not resolve dependencies for project
Failed to download artifact
```

**Solutions:**

1. **Check internet connectivity**
   ```bash
   # Test from cluster
   kubectl run test-curl --image=curlimages/curl --rm -it -- curl -I https://repo1.maven.org/maven2/
   ```

2. **Configure Maven mirror (if needed)**
   ```yaml
   # In integration-platform.yaml
   spec:
     build:
       maven:
         settings:
           mirrors:
           - id: central-mirror
             url: https://your-maven-mirror.com/maven2
   ```

3. **Increase build timeout**
   ```yaml
   spec:
     build:
       timeout: 30m
   ```

### Issue: Java compilation errors

**Symptoms:**
```
error: cannot find symbol
compilation failed
```

**Solutions:**

1. **Check Java syntax locally**
   ```bash
   # Use a Java IDE or javac to validate
   javac consumer.java
   ```

2. **Verify modeline directives**
   ```java
   // camel-k: language=java
   // camel-k: dependency=camel-http
   ```

3. **Check Camel K version compatibility**
   ```bash
   # Verify Camel K and Camel versions match
   kamel version
   ```

---

## Environment-Specific Issues

### Issue: DEV deployment works, but STAGING/PROD fails

**Possible Causes:**

1. **Different cluster configurations**
   - Verify kubeconfig is correct for each environment
   - Check network policies
   - Verify resource quotas

2. **Different security settings**
   ```bash
   # Check pod security policies
   kubectl get psp
   
   # Check network policies
   kubectl get networkpolicies -n camel-k-staging
   ```

3. **Registry differences**
   ```yaml
   # Dev uses insecure: true
   # Prod uses insecure: false
   
   # Ensure registry certificates are valid
   ```

### Issue: Environment-specific configuration not applied

**Symptoms:**
- Wrong log level in environment
- Resource limits not matching expected values

**Solutions:**

1. **Verify correct integration platform is applied**
   ```bash
   # Check which integration platform is active
   kubectl get integrationplatform -n camel-k-prod -o yaml
   
   # Should show prod-specific settings
   ```

2. **Re-apply integration platform**
   ```bash
   kubectl apply -f k8s/prod/integration-platform.yaml -n camel-k-prod
   
   # Verify
   kubectl get integrationplatform -n camel-k-prod -o yaml | grep -A 5 traits
   ```

3. **Check trait inheritance**
   ```bash
   # Integration traits override platform traits
   # Check integration for trait overrides
   kubectl get integration consumer-prod -n camel-k-prod -o yaml | grep -A 10 traits
   ```

---

## Quick Diagnostics Checklist

When deployment fails, run through this checklist:

```bash
# 1. Check GitHub Actions log
# Go to Actions tab → Select failed run → Review logs

# 2. Verify secrets are set
# Settings → Secrets → Check DEV/STAGING/PROD_KUBECONFIG exist

# 3. Test kubeconfig locally
echo "$KUBECONFIG_BASE64" | base64 -d > /tmp/kubeconfig
kubectl --kubeconfig=/tmp/kubeconfig get nodes

# 4. Check operator status
kubectl get deployment camel-k-operator -n camel-k-{env}
kubectl logs -n camel-k-{env} deployment/camel-k-operator --tail=50

# 5. Check integration status
kubectl get integration -n camel-k-{env}
kubectl describe integration consumer-{env} -n camel-k-{env}

# 6. Check pod status and logs
kubectl get pods -n camel-k-{env}
kubectl logs -l camel.apache.org/integration=consumer-{env} -n camel-k-{env} --tail=100

# 7. Check events
kubectl get events -n camel-k-{env} --sort-by='.lastTimestamp' | tail -20

# 8. Check integration platform
kubectl get integrationplatform -n camel-k-{env} -o yaml
```

---

## Getting More Help

### Enable Debug Logging

**In GitHub Actions:**
```bash
# Add to workflow for more verbose output
- name: Enable debug
  run: echo "ACTIONS_STEP_DEBUG=true" >> $GITHUB_ENV
```

**In Camel K:**
```bash
# Set operator log level
kubectl set env deployment/camel-k-operator -n camel-k-dev KAMEL_LOG_LEVEL=debug

# Deploy integration with debug logging
kamel run consumer.java --property logging.level.org.apache.camel=DEBUG
```

### Collect Diagnostics

```bash
# Create diagnostic bundle
mkdir -p diagnostics

# GitHub Actions
# Download logs from Actions tab → Select run → Download logs

# Kubernetes
kubectl get all -n camel-k-prod -o yaml > diagnostics/resources.yaml
kubectl get events -n camel-k-prod > diagnostics/events.txt
kubectl logs -n camel-k-prod deployment/camel-k-operator > diagnostics/operator.log
kubectl logs -l camel.apache.org/integration=consumer-prod -n camel-k-prod > diagnostics/integration.log

# Integration details
kubectl get integration consumer-prod -n camel-k-prod -o yaml > diagnostics/integration.yaml
kubectl get integrationplatform -n camel-k-prod -o yaml > diagnostics/platform.yaml
kubectl get integrationkit -n camel-k-prod -o yaml > diagnostics/kits.yaml

# Package for review
tar -czf diagnostics.tar.gz diagnostics/
```

---

## Common Error Messages & Solutions

| Error Message | Likely Cause | Solution |
|--------------|--------------|----------|
| `Secret not found` | GitHub Secret not configured | Add secret in GitHub Settings |
| `Unable to connect to server` | Invalid kubeconfig | Regenerate and update kubeconfig |
| `Forbidden` | Insufficient RBAC permissions | Update service account permissions |
| `IntegrationPlatform not found` | Platform not created | Apply integration-platform.yaml |
| `ImagePullBackOff` | Registry authentication failed | Check registry credentials |
| `CrashLoopBackOff` | Application error at startup | Check application logs |
| `OOMKilled` | Out of memory | Increase memory limits |
| `BuildFailed` | Build error | Check builder pod logs |

---

## Preventive Measures

1. **Regular maintenance**
   - Rotate secrets every 90 days
   - Update Camel K operator regularly
   - Monitor resource usage

2. **Pre-deployment checks**
   - Test locally with `kamel run --dev`
   - Verify CI passes before merging
   - Review deployment logs

3. **Monitoring setup**
   - Set up alerts for deployment failures
   - Monitor integration health
   - Track resource usage trends

4. **Documentation**
   - Document custom configurations
   - Keep runbooks updated
   - Share knowledge with team

---

**Still stuck?** Check:
- [SDLC-PIPELINE.md](../SDLC-PIPELINE.md) - Complete pipeline documentation
- [QUICK-START-CICD.md](../QUICK-START-CICD.md) - Setup guide
- [GitHub Actions Docs](https://docs.github.com/en/actions) - Official documentation
- [Camel K Docs](https://camel.apache.org/camel-k/) - Integration platform docs
