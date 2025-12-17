# Camel K Proof of Concept

A complete proof-of-concept implementation of Apache Camel K on Kubernetes, featuring an event-driven cryptocurrency price consumer.

## Overview

This project demonstrates:
- Apache Camel K operator deployment on local Kubernetes (kind)
- Event-driven integration patterns using Camel routes
- Real-time cryptocurrency price monitoring via CoinGecko API
- Cloud-native integration runtime with automatic build and deployment
- Kubernetes-native monitoring and management

## Architecture

```
Operating System (Linux)
  └── Docker Engine
      └── kind Cluster (Kubernetes v1.34.0)
          ├── Camel K Operator (namespace: camel-k)
          ├── Consumer Integration (namespace: default)
          │   └── Fetches Bitcoin prices every 60 seconds
          └── Headlamp UI (namespace: kube-system)
```

## Quick Start

### Prerequisites

- Docker
- kubectl
- Internet connectivity

### Installation

1. **Create kind cluster with local registry**:
   ```bash
   ./kind-registry-setup.sh
   ```

2. **Install Camel K**:
   ```bash
   ./setup.sh
   ```

3. **Deploy the consumer integration**:
   ```bash
   kamel run consumer.java
   ```

4. **View logs**:
   ```bash
   kamel log consumer
   # or
   kubectl logs -l camel.apache.org/integration=consumer -f
   ```

## What's Included

- **consumer.java** - Event-driven integration that fetches Bitcoin prices from CoinGecko API
- **setup.sh** - Automated Camel K installation script
- **kind-registry-setup.sh** - Local Kubernetes cluster setup with Docker registry
- **itp.yaml** - IntegrationPlatform configuration
- **DOCUMENTATION.md** - Comprehensive technical documentation (900+ lines)

## Technology Stack

| Component | Version |
|-----------|---------|
| Kubernetes | v1.34.0 |
| kind | v0.30.0 |
| Camel K Operator | 2.8.0 |
| Apache Camel | 4.8.5 |
| Camel Quarkus | 3.15.3 |

## Consumer Integration

The consumer integration:
- Triggers every 60 seconds via timer
- Calls CoinGecko API for Bitcoin price
- Logs events with timestamps
- Runs as Kubernetes CronJob pattern
- Auto-scales based on schedule

Sample output:
```
INFO  [crypto-price-consumer] 📡 Fetching crypto price event...
INFO  [crypto-price-consumer] 📬 Received event: {"bitcoin":{"usd":87234}}
INFO  [crypto-price-consumer] ✅ Event received at 2025-12-17 02:18:23 - Bitcoin Price: {"bitcoin":{"usd":87234}}
```

## Monitoring

### Web UI (Headlamp)

```bash
# Install and access Headlamp
kubectl create -f https://raw.githubusercontent.com/headlamp-k8s/headlamp/main/kubernetes-headlamp.yaml
kubectl port-forward -n kube-system svc/headlamp 8080:80
# Open http://localhost:8080
```

### Command Line

```bash
# List integrations
kamel get

# View logs
kamel log consumer

# Check status
kubectl get integration consumer

# View pods
kubectl get pods -l camel.apache.org/integration=consumer
```

## Documentation

See **[DOCUMENTATION.md](./DOCUMENTATION.md)** for complete technical documentation including:
- Detailed architecture
- Step-by-step installation guide
- Code walkthrough
- Troubleshooting guide
- Performance considerations
- Complete command reference

## Cleanup

```bash
# Delete integration
kamel delete consumer

# Delete Camel K
kubectl delete namespace camel-k

# Delete cluster
kind delete cluster

# Remove registry
docker stop kind-registry && docker rm kind-registry
```

## Resources

- [Apache Camel K Documentation](https://camel.apache.org/camel-k/latest/)
- [CoinGecko API](https://www.coingecko.com/en/api/documentation)
- [kind Documentation](https://kind.sigs.k8s.io/)
- [Headlamp](https://headlamp.dev/)

## License

This is a proof-of-concept project for learning and demonstration purposes.

---

**Created**: 2025-12-17
**Camel K Version**: 2.8.0
**Kubernetes Version**: v1.34.0
