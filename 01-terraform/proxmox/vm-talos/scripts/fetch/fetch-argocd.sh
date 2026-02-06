#!/bin/bash
# One-time fetch of Argo CD Helm chart into fetched/.
# Run from project root. Requires: helm.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
cd "$ROOT_DIR"

ARGOCD_VERSION="${ARGOCD_VERSION:-7.3.0}"

mkdir -p fetched

ARGOCD_TGZ="fetched/argo-cd-${ARGOCD_VERSION}.tgz"
if [ ! -f "${ARGOCD_TGZ}" ]; then
  echo "Pulling Argo CD Helm chart ${ARGOCD_VERSION} to ${ARGOCD_TGZ} ..."
  helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
  helm repo update
  helm pull argo/argo-cd --version "${ARGOCD_VERSION}" -d fetched
  [ -f "fetched/argo-cd-${ARGOCD_VERSION}.tgz" ] || { echo "Expected fetched/argo-cd-${ARGOCD_VERSION}.tgz"; exit 1; }
  echo "Done"
else
  echo "Argo CD chart already exists: ${ARGOCD_TGZ}"
fi

echo ""
echo "Local Argo CD chart ready: ${ARGOCD_TGZ}"
echo "Run ./scripts/deploy/start.sh and answer 'y' to 'Install Argo CD?' to install"
