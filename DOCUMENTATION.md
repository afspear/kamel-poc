# Camel K POC - Complete Documentation

## Table of Contents
1. [System Overview](#system-overview)
2. [Infrastructure Layer](#infrastructure-layer)
3. [Kubernetes Cluster Setup](#kubernetes-cluster-setup)
4. [Camel K Installation](#camel-k-installation)
5. [Integration Development](#integration-development)
6. [Monitoring and Management](#monitoring-and-management)
7. [Troubleshooting](#troubleshooting)
8. [References](#references)

---

## System Overview

This documentation describes a complete Camel K proof-of-concept implementation for event-driven integration patterns using Apache Camel K on Kubernetes.

### Technology Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| **Operating System** | Linux 6.14.0-1017-oem (Debian GNU/Linux 12) | Host operating system |
| **Container Runtime** | containerd 2.1.3 | Container execution engine |
| **Kubernetes** | v1.34.0 | Container orchestration platform |
| **kind** | v0.30.0 | Kubernetes in Docker - local cluster |
| **Camel K Operator** | 2.8.0 | Kubernetes operator for Apache Camel |
| **Camel K Client** | 2.8.0 | CLI tool for managing integrations |
| **Apache Camel** | 4.8.5 | Integration framework |
| **Camel Quarkus** | 3.15.3 | Cloud-native Camel runtime |
| **Camel K Runtime** | 3.15.3 | Kubernetes-native Camel runtime |

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ Host OS: Linux 6.14.0-1017-oem                                  │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ Docker Engine                                               │ │
│ │ ┌─────────────────────────────────────────────────────────┐ │ │
│ │ │ kind Cluster (Kubernetes v1.34.0)                       │ │ │
│ │ │                                                           │ │ │
│ │ │ ┌─────────────────┐  ┌────────────────────────────────┐ │ │ │
│ │ │ │ Namespace:      │  │ Namespace: default             │ │ │ │
│ │ │ │ camel-k         │  │                                │ │ │ │
│ │ │ │                 │  │ ┌────────────────────────────┐ │ │ │ │
│ │ │ │ ┌─────────────┐ │  │ │ Integration: consumer      │ │ │ │ │
│ │ │ │ │ Camel K     │ │  │ │ (CronJob Pods)             │ │ │ │ │
│ │ │ │ │ Operator    │ │  │ │                            │ │ │ │ │
│ │ │ │ │ (Deployment)│ │  │ │ Fetches Bitcoin price      │ │ │ │ │
│ │ │ │ └─────────────┘ │  │ │ from CoinGecko API         │ │ │ │ │
│ │ │ │                 │  │ │ Logs to stdout             │ │ │ │ │
│ │ │ │ ┌─────────────┐ │  │ └────────────────────────────┘ │ │ │ │
│ │ │ │ │Integration  │ │  │                                │ │ │ │
│ │ │ │ │Platform     │ │  └────────────────────────────────┘ │ │ │
│ │ │ │ └─────────────┘ │                                     │ │ │
│ │ │ └─────────────────┘                                     │ │ │
│ │ │                                                           │ │ │
│ │ │ ┌───────────────────────────────────────────────────────┐ │ │ │
│ │ │ │ Namespace: kube-system                                │ │ │ │
│ │ │ │ ┌───────────────┐                                     │ │ │ │
│ │ │ │ │ Headlamp UI   │ (Web UI for monitoring)            │ │ │ │
│ │ │ │ └───────────────┘                                     │ │ │ │
│ │ │ └───────────────────────────────────────────────────────┘ │ │ │
│ │ └─────────────────────────────────────────────────────────┘ │ │
│ │                                                               │ │
│ │ ┌─────────────────────────────────────────────────────────┐ │ │
│ │ │ Local Docker Registry (localhost:5001)                  │ │ │
│ │ └─────────────────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## Infrastructure Layer

### Operating System Details

- **Platform**: Linux x86_64
- **Kernel**: 6.14.0-1017-oem
- **Distribution**: Debian GNU/Linux 12 (bookworm)
- **Container Runtime**: containerd 2.1.3

### Prerequisites

Required software installations:
- Docker Engine (for running kind)
- kubectl (Kubernetes CLI)
- curl (for downloading releases)
- tar (for extracting archives)
- Internet connectivity (for pulling images and accessing APIs)

---

## Kubernetes Cluster Setup

### Local Registry Setup

A local Docker registry is configured to support Camel K's build process and avoid rate limits from public registries.

**Script**: `kind-registry-setup.sh`

#### What it does:

1. **Creates a Docker Registry Container**
   ```bash
   docker run -d --restart=always -p "127.0.0.1:5001:5000" \
     --name "kind-registry" registry:2
   ```
   - Runs on localhost:5001
   - Automatically restarts if it stops
   - Uses the official Docker registry:2 image

2. **Creates kind Cluster with Registry Configuration**
   ```yaml
   kind: Cluster
   apiVersion: kind.x-k8s.io/v1alpha4
   containerdConfigPatches:
   - |-
     [plugins."io.containerd.grpc.v1.cri".registry]
       config_path = "/etc/containerd/certs.d"
   ```

3. **Configures Registry Access on Cluster Nodes**
   - Creates `/etc/containerd/certs.d/kind-registry:5000/hosts.toml`
   - Configures HTTP access to the local registry
   - Applied to all kind cluster nodes

4. **Connects Registry to Cluster Network**
   ```bash
   docker network connect "kind" "kind-registry"
   ```
   - Allows pods to access registry at `kind-registry:5000`

5. **Documents Registry Configuration**
   - Creates ConfigMap in kube-public namespace
   - Follows KEP-1755 for local registry communication

### Cluster Verification

```bash
# Check cluster info
kubectl cluster-info

# Verify nodes
kubectl get nodes -o wide

# Check registry connectivity
curl http://localhost:5001/v2/_catalog
```

---

## Camel K Installation

### Installation Process

**Script**: `setup.sh`

This automated script handles the complete Camel K installation process.

#### Phase 1: Prerequisite Validation

```bash
# Checks for kubectl
command -v kubectl

# Verifies cluster access
kubectl cluster-info

# Validates connectivity
kubectl get nodes
```

#### Phase 2: Camel K CLI Installation

The script automatically:
1. Detects operating system and architecture
2. Fetches latest Camel K release from GitHub API
3. Downloads appropriate binary (kamel)
4. Installs to `/usr/local/bin/` or current directory
5. Makes binary executable

**Manual Installation Alternative**:
```bash
# Download latest release
VERSION=2.8.0
curl -L https://github.com/apache/camel-k/releases/download/v${VERSION}/camel-k-client-${VERSION}-linux-amd64.tar.gz \
  -o kamel.tar.gz

# Extract and install
tar -xzf kamel.tar.gz
sudo mv kamel /usr/local/bin/
chmod +x /usr/local/bin/kamel

# Verify
kamel version
```

#### Phase 3: Camel K Operator Deployment

The operator is deployed to the `camel-k` namespace.

**Namespace Creation**:
```bash
kubectl create namespace camel-k
```

**Operator Installation**:
```bash
# Using server-side apply to handle large CRDs
kubectl apply --server-side=true \
  -k "github.com/apache/camel-k/install/overlays/kubernetes/descoped?ref=v2.8.0" \
  -n camel-k
```

**What Gets Installed**:
- Custom Resource Definitions (CRDs):
  - `integrations.camel.apache.org`
  - `integrationplatforms.camel.apache.org`
  - `integrationkits.camel.apache.org`
  - `pipes.camel.apache.org`
  - `kameletbindings.camel.apache.org`
  - `kamelets.camel.apache.org`

- Operator Deployment:
  - Deployment: `camel-k-operator`
  - ServiceAccount: `camel-k-operator`
  - RBAC: ClusterRole and ClusterRoleBinding
  - Leader Election: ConfigMap and Lease resources

**Wait for Operator Readiness**:
```bash
kubectl wait --for=condition=available --timeout=120s \
  deployment/camel-k-operator -n camel-k
```

#### Phase 4: Integration Platform Configuration

**File**: `itp.yaml`

```yaml
apiVersion: camel.apache.org/v1
kind: IntegrationPlatform
metadata:
  labels:
    app: camel-k
  name: camel-k
  namespace: camel-k
spec:
  build:
    registry:
      address: registry.io
      organization: camel-k
      insecure: true
```

**Purpose**:
- Defines build configuration for integrations
- Specifies container registry settings
- Configures runtime profile (Kubernetes)
- Sets default build options

**Apply Configuration**:
```bash
kubectl apply -f itp.yaml -n camel-k
```

### Installation Verification

```bash
# Check operator pod
kubectl get pods -n camel-k

# Verify integration platform
kubectl get integrationplatform -n camel-k

# View operator logs
kubectl logs -n camel-k deployment/camel-k-operator

# Check CRDs
kubectl get crd | grep camel
```

---

## Integration Development

### Consumer Integration

**File**: `consumer.java`

#### Source Code

```java
// camel-k: language=java
// camel-k: dependency=camel-http
// camel-k: dependency=camel-file

import org.apache.camel.builder.RouteBuilder;

public class consumer extends RouteBuilder {
    @Override
    public void configure() throws Exception {

        // Poll a public API every minute for Bitcoin price updates
        from("timer:crypto-events?period=60000")
            .routeId("crypto-price-consumer")
            .log("📡 Fetching crypto price event...")
            .to("https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd")
            .convertBodyTo(String.class)
            .log("📬 Received event: ${body}")
            .log("✅ Event received at ${date:now:yyyy-MM-dd HH:mm:ss} - Bitcoin Price: ${body}");
    }
}
```

#### Code Explanation

**Modeline Directives** (Lines 1-3):
```java
// camel-k: language=java
// camel-k: dependency=camel-http
// camel-k: dependency=camel-file
```
- These special comments are parsed by Camel K
- `language=java`: Specifies Java DSL with runtime compilation
- `dependency=camel-http`: Includes HTTP component for REST calls
- `dependency=camel-file`: Includes file component (initially used, later removed)

**Route Definition**:

1. **Timer Component** (`from("timer:crypto-events?period=60000")`):
   - Creates a scheduled trigger
   - Fires every 60000ms (1 minute)
   - Named "crypto-events"
   - Camel K automatically converts this to a Kubernetes CronJob

2. **Route ID** (`.routeId("crypto-price-consumer")`):
   - Unique identifier for this route
   - Used in logs and monitoring
   - Appears in route management tools

3. **HTTP Request** (`.to("https://api.coingecko.com/api/v3/...")`):
   - REST API call to CoinGecko
   - Fetches Bitcoin price in USD
   - Returns JSON: `{"bitcoin":{"usd":87234}}`
   - Uses Camel's HTTP component

4. **Type Conversion** (`.convertBodyTo(String.class)`):
   - Converts HTTP response to String
   - Ensures consistent body type for logging

5. **Logging** (`.log(...)`):
   - Outputs to container stdout
   - Includes emoji for visual clarity
   - Uses Camel's Simple Expression Language for timestamps
   - Viewable via `kubectl logs` or monitoring UI

#### Deployment

**Command**:
```bash
kamel run consumer.java
```

**What Happens During Deployment**:

1. **Analysis Phase**:
   - Camel K parses modeline directives
   - Determines required dependencies
   - Identifies Java source code

2. **Build Phase**:
   - Creates an Integration custom resource
   - Builds container image with required dependencies
   - Packages Quarkus-based runtime
   - Pushes image to registry

3. **Deployment Phase**:
   - Creates Kubernetes resources
   - Deploys pod with compiled integration
   - Configures health checks and probes

4. **Runtime Phase**:
   - Pod starts and runs the Camel route
   - Timer triggers on schedule
   - Logs appear in pod output

**Generated Kubernetes Resources**:
```bash
# Integration custom resource
kubectl get integration consumer

# Generated pods (CronJob pattern)
kubectl get pods -l camel.apache.org/integration=consumer

# Integration kit (cached build)
kubectl get integrationkit
```

#### Integration Lifecycle

**Check Status**:
```bash
# Using kamel CLI
kamel get

# Using kubectl
kubectl get integration consumer

# Detailed status
kubectl describe integration consumer
```

**View Logs**:
```bash
# Stream logs using kamel
kamel log consumer

# Using kubectl
kubectl logs -l camel.apache.org/integration=consumer -f

# View specific pod
kubectl logs consumer-29432298-vq7mw
```

**Delete Integration**:
```bash
kamel delete consumer
```

---

## Monitoring and Management

### Headlamp Web UI

Headlamp provides a modern, user-friendly web interface for Kubernetes management.

#### Installation

```bash
# Deploy Headlamp
kubectl create -f https://raw.githubusercontent.com/headlamp-k8s/headlamp/main/kubernetes-headlamp.yaml

# Port forward to access
kubectl port-forward -n kube-system svc/headlamp 8080:80
```

#### Authentication Setup

Create service account with cluster admin access:

```bash
# Create service account
kubectl -n kube-system create serviceaccount headlamp-admin

# Bind cluster admin role
kubectl create clusterrolebinding headlamp-admin \
  --serviceaccount=kube-system:headlamp-admin \
  --clusterrole=cluster-admin

# Generate token
kubectl create token headlamp-admin -n kube-system
```

**Access**:
1. Navigate to http://localhost:8080
2. Paste the generated token
3. Click "Sign In"

#### Features Available

- **Pod Monitoring**: Real-time pod status and logs
- **Resource Management**: View deployments, services, ConfigMaps
- **Log Viewing**: Stream logs from any pod
- **Exec Shell**: Terminal access to containers
- **Resource Editing**: Edit YAML configurations
- **Events**: Kubernetes event stream
- **Metrics**: Resource utilization graphs

### Command-Line Monitoring

#### kamel CLI Commands

```bash
# List all integrations
kamel get

# View integration details
kamel describe consumer

# Stream logs
kamel log consumer

# Rebuild integration
kamel rebuild consumer

# Delete integration
kamel delete consumer
```

#### kubectl Commands

```bash
# Get all integrations
kubectl get integration

# Get pods for specific integration
kubectl get pods -l camel.apache.org/integration=consumer

# Watch pod status in real-time
kubectl get pods -w

# View integration events
kubectl get events --sort-by='.lastTimestamp'

# Describe integration resource
kubectl describe integration consumer

# Get integration YAML
kubectl get integration consumer -o yaml

# View operator logs
kubectl logs -n camel-k deployment/camel-k-operator -f
```

#### k9s Terminal UI (Optional)

k9s provides an interactive terminal UI for Kubernetes.

**Installation**:
```bash
# Using snap
sudo snap install k9s

# Or download binary
wget https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz
tar -xzf k9s_Linux_amd64.tar.gz
sudo mv k9s /usr/local/bin/
```

**Usage**:
```bash
k9s
```

**Key Features**:
- Navigate with arrow keys
- Press `/` to filter resources
- Press `l` to view logs
- Press `d` to describe resource
- Press `e` to edit resource
- Press `:pod` to switch to pods view
- Press `?` for help

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: File Write Errors

**Symptom**:
```
ERROR: Cannot store file: events/event-log.txt
Caused by: java.nio.file.NoSuchFileException: events/event-log.txt
```

**Root Cause**:
- Integration attempted to write to `events/event-log.txt`
- Parent directory `events/` doesn't exist in container
- Camel file component doesn't create parent directories by default

**Solutions**:

**Option A**: Remove file writing (implemented):
```java
// Instead of writing to file, just log
.log("✅ Event received at ${date:now:yyyy-MM-dd HH:mm:ss} - Bitcoin Price: ${body}")
```

**Option B**: Use /tmp directory:
```java
.to("file:/tmp?fileName=event-log.txt&fileExist=Append")
```

**Option C**: Configure PersistentVolume (production):
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: consumer-storage
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
# Mount in integration using trait
kamel run consumer.java -t mount.volumes=pvc:consumer-storage:/data
# Then write to: file:/data/events
```

#### Issue 2: Operator Not Starting

**Symptom**:
```
kubectl get pods -n camel-k
# Shows CrashLoopBackOff or ImagePullBackOff
```

**Debugging Steps**:
```bash
# Check pod status
kubectl describe pod -n camel-k <pod-name>

# View logs
kubectl logs -n camel-k <pod-name>

# Check events
kubectl get events -n camel-k --sort-by='.lastTimestamp'
```

**Common Causes**:
- Image pull failures: Check registry access
- Resource constraints: Increase node resources
- RBAC issues: Verify service account permissions

#### Issue 3: Integration Stuck in Building Phase

**Symptom**:
```bash
kamel get
# Shows: consumer   Building
```

**Debugging**:
```bash
# Check integration status
kubectl describe integration consumer

# View builder pod logs
kubectl logs -l camel.apache.org/integration=consumer -c builder

# Check integration kit
kubectl get integrationkit
kubectl describe integrationkit <kit-name>
```

**Common Causes**:
- Registry issues: Verify local registry is running
- Maven dependency failures: Check internet connectivity
- Resource limits: Integration builds need sufficient memory

#### Issue 4: CRD Annotation Size Errors

**Symptom**:
```
metadata.annotations: Too long: must have at most 262144 bytes
```

**Solution** (implemented in setup.sh):
```bash
# Use server-side apply
kubectl apply --server-side=true -k ...

# Or remove large annotations with kustomize patches
```

### Diagnostic Commands

```bash
# Complete cluster health check
kubectl get all --all-namespaces

# Check Camel K operator health
kubectl get deployment camel-k-operator -n camel-k
kubectl logs -n camel-k deployment/camel-k-operator --tail=50

# Verify integration platform
kubectl get integrationplatform -n camel-k -o yaml

# Check integration status
kubectl get integration consumer -o yaml | grep -A 10 status

# View all events
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20

# Check registry connectivity
docker ps | grep registry
curl http://localhost:5001/v2/_catalog
```

### Logs and Debugging

**Enable Debug Logging**:
```bash
# For integration
kamel run consumer.java --property logging.level.org.apache.camel=DEBUG

# For operator
kubectl set env deployment/camel-k-operator -n camel-k \
  KAMEL_LOG_LEVEL=debug
```

**View Detailed Logs**:
```bash
# Integration logs with timestamps
kubectl logs -l camel.apache.org/integration=consumer \
  --timestamps=true --tail=100

# Follow logs across pod restarts
kubectl logs -l camel.apache.org/integration=consumer -f --previous

# Export logs to file
kubectl logs -l camel.apache.org/integration=consumer > consumer.log
```

---

## Integration Behavior

### What the Consumer Does

1. **Every 60 seconds**:
   - Pod is created by Kubernetes (CronJob pattern)
   - Camel route starts
   - Timer fires immediately

2. **HTTP Request**:
   - Calls CoinGecko API: `https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd`
   - Receives JSON response: `{"bitcoin":{"usd":87234}}`

3. **Logging**:
   - Logs fetching message with emoji
   - Logs received event with JSON body
   - Logs formatted event with timestamp

4. **Completion**:
   - Route completes after processing 1 message (duration max 1)
   - Pod shuts down gracefully
   - Status changes to "Completed"
   - Next pod scheduled for 60 seconds later

### Sample Log Output

```
INFO  [org.apa.cam.k.Runtime] Apache Camel K Runtime 3.15.3
INFO  [org.apa.cam.qua.cor.CamelBootstrapRecorder] Apache Camel Quarkus 3.15.3 is starting
INFO  [org.apa.cam.mai.MainSupport] Apache Camel (Main) 4.8.5 is starting
INFO  [org.apa.cam.imp.eng.AbstractCamelContext] Apache Camel 4.8.5 (camel-1) is starting
INFO  [org.apa.cam.imp.eng.AbstractCamelContext] Routes startup (total:1)
INFO  [org.apa.cam.imp.eng.AbstractCamelContext]     Started crypto-price-consumer (timer://camel-k-overridden-cron)
INFO  [io.quarkus] camel-k-integration 2.8.0 on JVM (powered by Quarkus 3.15.4) started in 20.391s
INFO  [crypto-price-consumer] 📡 Fetching crypto price event...
INFO  [crypto-price-consumer] 📬 Received event: {"bitcoin":{"usd":87234}}
INFO  [crypto-price-consumer] ✅ Event received at 2025-12-17 02:18:23 - Bitcoin Price: {"bitcoin":{"usd":87234}}
INFO  [org.apa.cam.mai.MainDurationEventNotifier] Duration max messages triggering shutdown of the JVM
INFO  [org.apa.cam.imp.eng.AbstractCamelContext] Apache Camel 4.8.5 (camel-1) is shutting down (timeout:45s)
```

---

## Performance and Resource Usage

### Integration Resource Requirements

**Pod Resources** (defaults):
- CPU Request: 100m
- Memory Request: 256Mi
- Ephemeral Storage: ~500Mi for image layers

**Operator Resources**:
- CPU Request: 100m
- Memory Request: 512Mi

### Build Process

**First Build**:
- Time: ~2-3 minutes
- Downloads Maven dependencies
- Compiles Java code with JBang
- Builds Quarkus native image
- Pushes to registry

**Subsequent Builds** (with kit reuse):
- Time: ~10-30 seconds
- Reuses existing IntegrationKit
- Only updates source code
- Fast redeploy

### Scaling Considerations

**Horizontal Scaling**:
```bash
# Scale integration replicas
kubectl scale integration consumer --replicas=3
```

**Cron Pattern**:
- Each timer trigger creates a new pod
- Pod completes and terminates
- Natural scaling based on schedule
- No persistent pods (stateless)

---

## References

### Official Documentation

- **Apache Camel K**: https://camel.apache.org/camel-k/latest/
- **Apache Camel**: https://camel.apache.org/
- **Kubernetes**: https://kubernetes.io/docs/
- **kind**: https://kind.sigs.k8s.io/
- **Headlamp**: https://headlamp.dev/

### GitHub Repositories

- **Camel K**: https://github.com/apache/camel-k
- **Camel**: https://github.com/apache/camel
- **Headlamp**: https://github.com/headlamp-k8s/headlamp
- **kind**: https://github.com/kubernetes-sigs/kind

### API References

- **CoinGecko API**: https://www.coingecko.com/en/api/documentation
- **Camel Timer Component**: https://camel.apache.org/components/latest/timer-component.html
- **Camel HTTP Component**: https://camel.apache.org/components/latest/http-component.html
- **Camel File Component**: https://camel.apache.org/components/latest/file-component.html

### Camel K Resources

- **Examples**: https://github.com/apache/camel-k-examples
- **Traits**: https://camel.apache.org/camel-k/latest/traits/traits.html
- **CLI Reference**: https://camel.apache.org/camel-k/latest/cli/cli.html

---

## Appendix: Quick Reference

### Essential Commands

```bash
# Cluster Management
kind create cluster
kind delete cluster
kubectl cluster-info
kubectl get nodes

# Camel K Operations
kamel install
kamel run consumer.java
kamel get
kamel log consumer
kamel delete consumer
kamel version

# Kubernetes Resources
kubectl get integration
kubectl get integrationplatform
kubectl get integrationkit
kubectl get pods -l camel.apache.org/integration=consumer
kubectl logs -l camel.apache.org/integration=consumer -f

# Monitoring
kubectl get events --sort-by='.lastTimestamp'
kubectl top pods
kubectl describe integration consumer

# Cleanup
kamel delete consumer
kubectl delete namespace camel-k
kind delete cluster
docker stop kind-registry && docker rm kind-registry
```

### Directory Structure

```
kamel-poc/
├── consumer.java           # Consumer integration source
├── setup.sh                # Camel K installation script
├── kind-registry-setup.sh  # Cluster and registry setup
├── itp.yaml                # Integration platform configuration
└── DOCUMENTATION.md        # This file
```

### Namespace Layout

```
default              # Consumer integration runs here
camel-k              # Operator and IntegrationPlatform
kube-system          # Headlamp UI and system components
kube-public          # Registry ConfigMap
```

---

## Summary

This POC demonstrates a complete Camel K setup on local Kubernetes (kind) with:

1. **Infrastructure**: Local kind cluster with Docker registry
2. **Platform**: Camel K operator managing integration lifecycle
3. **Integration**: Event-driven consumer fetching cryptocurrency prices
4. **Monitoring**: Headlamp web UI for cluster management
5. **Automation**: Scripts for reproducible setup

The system successfully implements a cloud-native integration pattern using Apache Camel K, showcasing automatic build, deployment, and runtime management of integration workloads on Kubernetes.

**Total Setup Time**: ~5-10 minutes
**Integration Deploy Time**: ~2-3 minutes (first build), ~10-30 seconds (subsequent)
**Resource Footprint**: ~1 CPU core, ~2GB RAM

---

*Documentation generated: 2025-12-17*
*Camel K Version: 2.8.0*
*Kubernetes Version: v1.34.0*
