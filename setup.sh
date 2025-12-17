#!/bin/bash

set -e  # Exit on error

echo "=========================================="
echo "Camel K POC Setup Script"
echo "=========================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[ℹ]${NC} $1"
}

# Check for kubectl
echo ""
print_info "Checking for kubectl..."
if command_exists kubectl; then
    print_status "kubectl found: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
else
    print_error "kubectl not found. Please install kubectl first."
    echo "Visit: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

# Check for Kubernetes cluster access
echo ""
print_info "Checking Kubernetes cluster access..."
if kubectl cluster-info >/dev/null 2>&1; then
    print_status "Kubernetes cluster accessible"
    kubectl cluster-info | head -n 1
else
    print_error "Cannot access Kubernetes cluster."
    echo ""
    echo "Options to get a cluster running:"
    echo "  1. Docker Desktop: Enable Kubernetes in settings"
    echo "  2. Minikube: minikube start"
    echo "  3. Kind: kind create cluster"
    exit 1
fi

# Check for kamel CLI
echo ""
print_info "Checking for Camel K CLI (kamel)..."
if command_exists kamel; then
    print_status "kamel found: $(kamel version 2>/dev/null || echo 'installed')"
else
    print_info "kamel CLI not found. Installing..."
    
    # Detect OS and architecture
    OS="$(uname -s)"
    ARCH="$(uname -m)"
    
    case "${OS}" in
        Linux*)     PLATFORM=linux;;
        Darwin*)    PLATFORM=mac;;
        MINGW*|MSYS*|CYGWIN*)    PLATFORM=windows;;
        *)          
            print_error "Unsupported OS: ${OS}"
            exit 1
            ;;
    esac
    
    case "${ARCH}" in
        x86_64|amd64)   ARCH_SUFFIX="amd64";;
        arm64|aarch64)  ARCH_SUFFIX="arm64";;
        *)          
            print_error "Unsupported architecture: ${ARCH}"
            exit 1
            ;;
    esac
    
    # Get latest release
    LATEST_VERSION=$(curl -s https://api.github.com/repos/apache/camel-k/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
    
    if [ -z "$LATEST_VERSION" ]; then
        print_error "Could not determine latest Camel K version"
        exit 1
    fi
    
    print_info "Latest Camel K version: v${LATEST_VERSION}"
    
    # Download URL based on platform
    if [ "$PLATFORM" = "windows" ]; then
        DOWNLOAD_URL="https://github.com/apache/camel-k/releases/download/v${LATEST_VERSION}/camel-k-client-${LATEST_VERSION}-${PLATFORM}-${ARCH_SUFFIX}.tar.gz"
        BINARY_NAME="kamel.exe"
    else
        DOWNLOAD_URL="https://github.com/apache/camel-k/releases/download/v${LATEST_VERSION}/camel-k-client-${LATEST_VERSION}-${PLATFORM}-${ARCH_SUFFIX}.tar.gz"
        BINARY_NAME="kamel"
    fi
    
    # Save current directory
    INSTALL_DIR=$(pwd)
    
    # Download and install
    TEMP_DIR=$(mktemp -d)
    print_info "Downloading from: ${DOWNLOAD_URL}"
    
    if curl -L -f -o "${TEMP_DIR}/kamel.tar.gz" "${DOWNLOAD_URL}"; then
        # Extract in temp directory
        tar -xzf "${TEMP_DIR}/kamel.tar.gz" -C "${TEMP_DIR}"
        
        # Try to install to /usr/local/bin first, fall back to current directory
        if [ -w /usr/local/bin ]; then
            cp "${TEMP_DIR}/${BINARY_NAME}" /usr/local/bin/
            chmod +x /usr/local/bin/"${BINARY_NAME}"
            print_status "kamel installed to /usr/local/bin/"
        elif sudo -n true 2>/dev/null; then
            sudo cp "${TEMP_DIR}/${BINARY_NAME}" /usr/local/bin/
            sudo chmod +x /usr/local/bin/"${BINARY_NAME}"
            print_status "kamel installed to /usr/local/bin/ (with sudo)"
        else
            cp "${TEMP_DIR}/${BINARY_NAME}" "${INSTALL_DIR}/"
            chmod +x "${INSTALL_DIR}/${BINARY_NAME}"
            print_status "kamel installed to ${INSTALL_DIR}/"
            print_info "Consider adding to PATH or moving manually: sudo mv ${BINARY_NAME} /usr/local/bin/"
            
            # Add current directory to PATH for this session
            export PATH="${INSTALL_DIR}:${PATH}"
        fi
        
        rm -rf "${TEMP_DIR}"
    else
        print_error "Failed to download kamel CLI"
        print_info "You can manually download from: https://github.com/apache/camel-k/releases"
        rm -rf "${TEMP_DIR}"
        exit 1
    fi
fi

# Verify kamel is accessible
if ! command_exists kamel; then
    # Check if it's in current directory
    if [ -f "./kamel" ]; then
        print_info "kamel found in current directory, adding to PATH for this session"
        export PATH="$(pwd):${PATH}"
    else
        print_error "kamel not found in PATH after installation"
        exit 1
    fi
fi

# Install Camel K operator
echo ""
print_info "Installing Camel K operator..."

# Check if operator already exists
if kubectl get deployment -n camel-k camel-k-operator >/dev/null 2>&1; then
    print_status "Camel K operator already installed"
else
    OPERATOR_VERSION="2.8.0"
    print_info "Installing operator version ${OPERATOR_VERSION}..."
    
    # Create namespace
    kubectl create namespace camel-k 2>/dev/null || true
    
    # Download manifests and apply with annotation size workaround
    TEMP_DIR=$(mktemp -d)
    
    print_info "Downloading and patching manifests..."
    
    # Download the manifests
    if curl -L -f "https://raw.githubusercontent.com/apache/camel-k/v${OPERATOR_VERSION}/install/resources/kubernetes/descoped/kustomization.yaml" -o "${TEMP_DIR}/kustomization.yaml" 2>/dev/null; then
        cd "${TEMP_DIR}"
        
        # Create a kustomization that removes large annotations
        cat > kustomization-patched.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- https://github.com/apache/camel-k/install/overlays/kubernetes/descoped?ref=v${OPERATOR_VERSION}

patches:
- target:
    kind: CustomResourceDefinition
    name: integrations.camel.apache.org
  patch: |-
    - op: remove
      path: /metadata/annotations/kubectl.kubernetes.io~1last-applied-configuration
- target:
    kind: CustomResourceDefinition
    name: pipes.camel.apache.org
  patch: |-
    - op: remove
      path: /metadata/annotations/kubectl.kubernetes.io~1last-applied-configuration
EOF
        
        kubectl apply -k . -n camel-k 2>&1 | grep -v "Warning: unrecognized format" || true
        cd - > /dev/null
        rm -rf "${TEMP_DIR}"
    else
        print_info "Trying alternative installation method..."
        
        # Fallback: Apply CRDs individually with server-side apply
        kubectl apply --server-side=true -k "github.com/apache/camel-k/install/overlays/kubernetes/descoped?ref=v${OPERATOR_VERSION}" -n camel-k 2>&1 | grep -v "Warning: unrecognized format" || true
    fi
    
    print_status "Camel K operator installation completed"
fi

# Verify installation
echo ""
print_info "Verifying Camel K installation..."
print_info "Waiting for operator to be ready (this may take a minute)..."

# Wait for the operator deployment to exist first
for i in {1..30}; do
    if kubectl get deployment camel-k-operator -n camel-k >/dev/null 2>&1; then
        print_status "Operator deployment found"
        break
    fi
    if [ $i -eq 30 ]; then
        print_info "Operator deployment not found yet. It may still be creating..."
        kubectl get all -n camel-k
    fi
    sleep 2
done

# Now wait for it to be available
if kubectl wait --for=condition=available --timeout=120s deployment/camel-k-operator -n camel-k 2>/dev/null; then
    print_status "Camel K operator is running"
else
    print_info "Checking operator status..."
    kubectl get pods -n camel-k
fi

# Create a default IntegrationPlatform
echo ""
print_info "Creating default IntegrationPlatform..."
cat <<EOF | kubectl apply -f - -n camel-k
apiVersion: camel.apache.org/v1
kind: IntegrationPlatform
metadata:
  name: camel-k
  namespace: camel-k
spec:
  profile: Kubernetes
EOF

print_status "IntegrationPlatform created"

echo ""
echo "=========================================="
print_status "Setup Complete!"
echo "=========================================="
echo ""
echo "Installed components:"
kamel version 2>/dev/null || echo "  kamel CLI: installed"
echo ""
echo "Verify installation:"
echo "  kubectl get pods -n camel-k"
echo "  kubectl get integrationplatform -n camel-k"
echo ""
echo "Next steps:"
echo "  1. Create your integration files (producer.java, consumer.java)"
echo "  2. Deploy: kamel run producer.java -n camel-k"
echo "  3. Check status: kamel get -n camel-k"
echo "  4. View logs: kamel log producer -n camel-k"
echo ""