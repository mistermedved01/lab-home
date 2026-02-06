#!/bin/bash
# Tear down cluster (Terraform + kubeconfig).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
cd "$ROOT_DIR"

if [ -z "${TALOS_CLUSTER_NAME:-}" ] && [ -f terraform.tfvars ]; then
  TALOS_CLUSTER_NAME=$(grep -E "^\s*talos_cluster_name\s*=" terraform.tfvars 2>/dev/null | sed -E 's/.*=\s*"([^"]+)".*/\1/' | head -1 | tr -d ' \r')
fi
TALOS_CLUSTER_NAME="${TALOS_CLUSTER_NAME:-talos-cluster-01}"

VARFILE=""
[ -f terraform.tfvars ] && VARFILE="-var-file=terraform.tfvars"
terraform destroy -auto-approve $VARFILE

if [ -f "${HOME}/.kube/${TALOS_CLUSTER_NAME}.yaml" ]; then
  rm "${HOME}/.kube/${TALOS_CLUSTER_NAME}.yaml"
fi
