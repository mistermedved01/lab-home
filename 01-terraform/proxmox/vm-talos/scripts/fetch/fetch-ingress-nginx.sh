#!/bin/bash
# One-time fetch of ingress-nginx Helm chart into fetched/.
# Run from project root. Requires: helm.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
cd "$ROOT_DIR"

INGRESS_NGINX_VERSION="${INGRESS_NGINX_VERSION:-4.11.3}"

mkdir -p fetched

INGRESS_NGINX_TGZ="fetched/ingress-nginx-${INGRESS_NGINX_VERSION}.tgz"
if [ ! -f "${INGRESS_NGINX_TGZ}" ]; then
  echo "Pulling ingress-nginx Helm chart ${INGRESS_NGINX_VERSION} to ${INGRESS_NGINX_TGZ} ..."
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
  helm repo update
  helm pull ingress-nginx/ingress-nginx --version "${INGRESS_NGINX_VERSION}" -d fetched
  [ -f "fetched/ingress-nginx-${INGRESS_NGINX_VERSION}.tgz" ] || { echo "Expected fetched/ingress-nginx-${INGRESS_NGINX_VERSION}.tgz"; exit 1; }
  echo "Done."
else
  echo "ingress-nginx chart already exists: ${INGRESS_NGINX_TGZ}"
fi

echo ""
echo "Local ingress-nginx chart ready: ${INGRESS_NGINX_TGZ}"
echo "Run ./scripts/deploy/start.sh and answer 'y' to 'Install NGINX Ingress Controller?' to install"