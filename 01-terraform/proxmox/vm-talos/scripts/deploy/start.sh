#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
cd "$ROOT_DIR"

TFVARS="terraform.tfvars"
if [ ! -f "${TFVARS}" ]; then
  echo "Error: ${TFVARS} not found"
  echo "Copy terraform.tfvars.example to terraform.tfvars and edit"
  exit 1
fi

get_tfvars_var() {
  grep -E "^\s*${1}\s*=" "${TFVARS}" 2>/dev/null | sed -E 's/.*=\s*"([^"]+)".*/\1/' | head -1 | tr -d ' \r'
}

TALOS_CLUSTER_NAME=$(get_tfvars_var talos_cluster_name)
TALOS_VERSION=$(get_tfvars_var talos_version)
TALOS_CLUSTER_NAME="${TALOS_CLUSTER_NAME:-talos-cluster-01}"
TALOS_VERSION="${TALOS_VERSION:-1.10.6}"

ARGOCD_VERSION="${ARGOCD_VERSION:-7.3.0}"
INGRESS_NGINX_VERSION="${INGRESS_NGINX_VERSION:-4.11.3}"

ARGOCD_TGZ="fetched/argo-cd-${ARGOCD_VERSION}.tgz"
INGRESS_NGINX_TGZ="fetched/ingress-nginx-${INGRESS_NGINX_VERSION}.tgz"

TALOS_IMAGE_FILE_ID=$(get_tfvars_var talos_image_file_id)
if [ -z "${TALOS_IMAGE_FILE_ID}" ]; then
  echo "Error: talos_image_file_id not set in ${TFVARS}."
  echo "Upload the Talos image to Proxmox (Datacenter -> Storage -> local -> ISO Images), then set in terraform.tfvars:"
  echo '  talos_image_file_id = "local:iso/talos-1.10.6-amd64.img"'
  exit 1
fi

confirm() {
  local message="$1"
  printf "%s (y/n): " "$message"
  read -r response
  [[ "$response" == "y" ]]
}

check_dependencies() {
  echo "Checking required tools (terraform, helm, kubectl)..."
  local missing=()
  for t in terraform helm kubectl; do
    if command -v "$t" &>/dev/null; then
      echo "  $t: found"
    else
      missing+=("$t")
      echo "  $t: not found"
    fi
  done
  if [ ${#missing[@]} -ne 0 ]; then
    echo ""
    echo "Error: Missing required tools: ${missing[*]}"
    echo "Install them and ensure they are on PATH, then run the script again"
    exit 1
  fi
  echo "All required tools are available"
}

check_dependencies

echo "Using Talos image in Proxmox: ${TALOS_IMAGE_FILE_ID}"
echo "CNI: Flannel (Talos built-in)"
echo ""

terraform init -input=false 2>&1 || true

set +e
tfplan=$(terraform plan -out=tfplan -var-file="${TFVARS}" 2>&1)
plan_exit=$?
set -e
echo "$tfplan"
[ $plan_exit -eq 0 ] || { echo "Terraform plan failed"; exit 1; }

if ! confirm "Apply?"; then
  echo "Aborted"
  exit 0
fi
terraform apply tfplan

if confirm "Save kubeconfig?"; then
  KUBECONFIG_FILE="${HOME}/.kube/${TALOS_CLUSTER_NAME}.yaml"
  terraform output -raw kubeconfig > "${KUBECONFIG_FILE}"
  echo "Waiting for cluster (initial 60s pause, then up to 5 min)..."
  sleep 60
  for i in {1..60}; do
    if kubectl --kubeconfig "${KUBECONFIG_FILE}" cluster-info &>/dev/null; then
      echo "Cluster is ready"
      kubectl --kubeconfig "${KUBECONFIG_FILE}" cluster-info | head -1
      break
    fi
    if [ "$i" -eq 60 ]; then
      echo "Cluster still not ready after 5 min"
      echo "Last error:"
      kubectl --kubeconfig "${KUBECONFIG_FILE}" cluster-info 2>&1 || true
      echo ""
      echo "Check: control plane VM running in Proxmox, IP reachable (ping), port 6443 open"
    else
      echo "Attempt $i/60..."
      if [ $((i % 3)) -eq 0 ]; then
        kubectl --kubeconfig "${KUBECONFIG_FILE}" cluster-info 2>&1 | head -1 || true
      fi
      sleep 5
    fi
  done
fi

if confirm "Install Argo CD?"; then
  KUBECONFIG_FILE="${HOME}/.kube/${TALOS_CLUSTER_NAME}.yaml"
  if [ ! -f "${ARGOCD_TGZ}" ]; then
    echo "Argo CD chart not found. Expected ${ARGOCD_TGZ}"
    echo "Run: ./scripts/fetch/fetch-argocd.sh"
  else
    echo "Checking cluster..."
    if ! kubectl --kubeconfig "${KUBECONFIG_FILE}" cluster-info &>/dev/null; then
      echo "Cluster unreachable. Fix kubeconfig or wait, then retry Argo CD install"
      if ! confirm "Continue anyway?"; then
        exit 0
      fi
    fi
    echo ""
    echo "Creating argocd namespace and Redis secret (redisSecretInit disabled for Argo CD v2.11+ compatibility)..."
    kubectl --kubeconfig "${KUBECONFIG_FILE}" create namespace argocd --dry-run=client -o yaml | kubectl --kubeconfig "${KUBECONFIG_FILE}" apply -f -
    if ! kubectl --kubeconfig "${KUBECONFIG_FILE}" get secret argocd-redis -n argocd &>/dev/null; then
      kubectl --kubeconfig "${KUBECONFIG_FILE}" create secret generic argocd-redis \
        --from-literal=auth="$(openssl rand -base64 32)" \
        -n argocd
    fi
    echo "Installing Argo CD from local chart..."
    helm upgrade --kubeconfig "${KUBECONFIG_FILE}" --install argocd "${ARGOCD_TGZ}" \
      --namespace argocd \
      --create-namespace \
      --values platform/argocd/values.yaml \
      --wait \
      --timeout=10m
    if [ $? -ne 0 ]; then
      echo "Argo CD installation failed"
      exit 1
    fi
    echo "Argo CD installed"
  fi
fi

if confirm "Install NGINX Ingress Controller?"; then
  KUBECONFIG_FILE="${HOME}/.kube/${TALOS_CLUSTER_NAME}.yaml"
  if [ ! -f "${INGRESS_NGINX_TGZ}" ]; then
    echo "ingress-nginx chart not found. Expected ${INGRESS_NGINX_TGZ}"
    echo "Run: ./scripts/fetch/fetch-ingress-nginx.sh"
  else
    echo "Checking cluster..."
    if ! kubectl --kubeconfig "${KUBECONFIG_FILE}" cluster-info &>/dev/null; then
      echo "Cluster unreachable. Fix kubeconfig or wait, then retry"
      if ! confirm "Continue anyway?"; then
        exit 0
      fi
    fi
    echo ""
    echo "Installing NGINX Ingress Controller from local chart..."
    helm upgrade --kubeconfig "${KUBECONFIG_FILE}" --install ingress-nginx "${INGRESS_NGINX_TGZ}" \
      --namespace ingress-nginx \
      --create-namespace \
      --values platform/ingress-nginx/values.yaml \
      --wait \
      --timeout=5m
    if [ $? -ne 0 ]; then
      echo "NGINX Ingress installation failed"
      exit 1
    fi
    echo "NGINX Ingress Controller installed"
    echo "HTTP NodePort: 30080, HTTPS NodePort: 30443. IngressClass 'nginx' is default"
  fi
fi

# Summary at the end (cluster reachable)
KUBECONFIG_FILE="${HOME}/.kube/${TALOS_CLUSTER_NAME}.yaml"
if [ -f "${KUBECONFIG_FILE}" ] && kubectl --kubeconfig "${KUBECONFIG_FILE}" cluster-info &>/dev/null; then
  echo ""
  echo "========== Summary =========="
  echo ""
  echo "Node IPs:"
  kubectl --kubeconfig "${KUBECONFIG_FILE}" get nodes -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}' 2>/dev/null | sed 's/^/  /'
  if kubectl --kubeconfig "${KUBECONFIG_FILE}" get ns argocd &>/dev/null; then
    ARGOCD_URL=$(grep -E '^\s*url:' platform/argocd/values.yaml 2>/dev/null | head -1 | sed -E "s/.*url:[[:space:]]*//; s/[\"']//g" | tr -d ' \r')
    [ -z "$ARGOCD_URL" ] && ARGOCD_URL="https://argocd.lab-home.com:30443"
    echo ""
    echo "Argo CD:"
    echo "  URL: $ARGOCD_URL"
    echo "  User: admin"
    echo "  Password: $(kubectl --kubeconfig "${KUBECONFIG_FILE}" -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)"
    echo ""
  fi
  echo "============================="
fi