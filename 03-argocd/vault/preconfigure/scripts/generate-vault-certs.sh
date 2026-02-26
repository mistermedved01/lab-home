#!/usr/bin/env bash
# Generate CA and TLS certs for Vault server and Vault Agent Injector.
# Usage: ./generate-vault-certs.sh
#   Интерактивно запрашивает: имя проекта, namespace, release.
#   Либо без вопросов: ./generate-vault-certs.sh <PROJECT> [NAMESPACE] [RELEASE]
# Requires: openssl
# Output: PEM в keys/<PROJECT>/; подсказки для preconfigure/<PROJECT>/ и custom-values.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR=""

# --- Ввод параметров: интерактивно или из аргументов ---
if [[ -n "${1:-}" ]]; then
  PROJECT="$1"
  NAMESPACE="${2:-vault}"
  RELEASE="${3:-vault}"
else
  echo "Имя проекта (например lab-home):"
  read -r PROJECT
  PROJECT="${PROJECT// /}"
  if [[ -z "$PROJECT" ]]; then
    echo "Error: имя проекта не задано." >&2
    exit 1
  fi
  echo "Namespace K8s для Vault [vault]:"
  read -r NAMESPACE
  NAMESPACE="${NAMESPACE:-vault}"
  echo "Имя Helm-релиза (fullnameOverride) [vault]:"
  read -r RELEASE
  RELEASE="${RELEASE:-vault}"
fi

OUT_DIR="$VAULT_DIR/keys/$PROJECT"

cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

if ! command -v openssl &>/dev/null; then
  echo "Error: openssl is required. Install OpenSSL or run in WSL/Git Bash." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
TMP_DIR="$(mktemp -d)"

# --- CA ---
echo "Generating CA..."
openssl genrsa -out "$OUT_DIR/vault-ca.key" 4096
openssl req -x509 -new -nodes -key "$OUT_DIR/vault-ca.key" -sha256 -days 3650 \
  -out "$OUT_DIR/vault-ca.crt" \
  -subj "/O=${PROJECT}/OU=vault/CN=${PROJECT} Vault CA"

# --- Vault server cert SANs ---
SERVER_SANS="DNS:${RELEASE},DNS:${RELEASE}.${NAMESPACE}.svc,DNS:${RELEASE}.${NAMESPACE}.svc.cluster.local"
SERVER_SANS="${SERVER_SANS},DNS:${RELEASE}-active,DNS:${RELEASE}-active.${NAMESPACE},DNS:${RELEASE}-active.${NAMESPACE}.svc,DNS:${RELEASE}-active.${NAMESPACE}.svc.cluster.local"
SERVER_SANS="${SERVER_SANS},DNS:${RELEASE}-internal,DNS:${RELEASE}-internal.${NAMESPACE}.svc,DNS:${RELEASE}-internal.${NAMESPACE}.svc.cluster.local"
SERVER_SANS="${SERVER_SANS},DNS:${RELEASE}-0.${RELEASE}-internal,DNS:${RELEASE}-0.${RELEASE}-internal.${NAMESPACE}.svc,DNS:${RELEASE}-0.${RELEASE}-internal.${NAMESPACE}.svc.cluster.local"
SERVER_SANS="${SERVER_SANS},DNS:${RELEASE}-1.${RELEASE}-internal,DNS:${RELEASE}-2.${RELEASE}-internal"
SERVER_SANS="${SERVER_SANS},DNS:localhost,IP:127.0.0.1"

# --- Vault server cert (vault-crt) ---
echo "Generating Vault server cert (vault-crt)..."
cat > "$TMP_DIR/server.cnf" << EOF
[req]
distinguished_name = req_dn
req_extensions = v3_req
[req_dn]
[v3_req]
subjectAltName = $SERVER_SANS
EOF
openssl genrsa -out "$OUT_DIR/vault-crt.key" 2048
openssl req -new -key "$OUT_DIR/vault-crt.key" -out "$TMP_DIR/vault-crt.csr" \
  -subj "/O=${PROJECT}/OU=vault/CN=${RELEASE}.${NAMESPACE}.svc" \
  -config "$TMP_DIR/server.cnf"
openssl x509 -req -in "$TMP_DIR/vault-crt.csr" -CA "$OUT_DIR/vault-ca.crt" -CAkey "$OUT_DIR/vault-ca.key" \
  -CAcreateserial -out "$OUT_DIR/vault-crt.crt" -sha256 -days 3650 \
  -extensions v3_req -extfile "$TMP_DIR/server.cnf"

# --- Injector cert SANs ---
INJECTOR_SANS="DNS:${RELEASE}-agent-injector-svc,DNS:${RELEASE}-agent-injector-svc.${NAMESPACE},DNS:${RELEASE}-agent-injector-svc.${NAMESPACE}.svc,DNS:${RELEASE}-agent-injector-svc.${NAMESPACE}.svc.cluster.local"

# --- Vault Agent Injector cert (vault-injector-crt) ---
echo "Generating Vault Agent Injector cert (vault-injector-crt)..."
cat > "$TMP_DIR/injector.cnf" << EOF
[req]
distinguished_name = req_dn
req_extensions = v3_req
[req_dn]
[v3_req]
subjectAltName = $INJECTOR_SANS
EOF
openssl genrsa -out "$OUT_DIR/vault-injector-crt.key" 2048
openssl req -new -key "$OUT_DIR/vault-injector-crt.key" -out "$TMP_DIR/vault-injector-crt.csr" \
  -subj "/O=${PROJECT}/OU=vault-injector/CN=${RELEASE}-agent-injector-svc.${NAMESPACE}.svc" \
  -config "$TMP_DIR/injector.cnf"
openssl x509 -req -in "$TMP_DIR/vault-injector-crt.csr" -CA "$OUT_DIR/vault-ca.crt" -CAkey "$OUT_DIR/vault-ca.key" \
  -CAcreateserial -out "$OUT_DIR/vault-injector-crt.crt" -sha256 -days 3650 \
  -extensions v3_req -extfile "$TMP_DIR/injector.cnf"

# --- Base64 for Kubernetes (single line, portable) ---
b64() { base64 < "$1" | tr -d '\n'; }
CA_B64="$(b64 "$OUT_DIR/vault-ca.crt")"
echo -n "$CA_B64" > "$OUT_DIR/caBundle.b64"
VAULT_CRT_B64="$(b64 "$OUT_DIR/vault-crt.crt")"
VAULT_KEY_B64="$(b64 "$OUT_DIR/vault-crt.key")"
INJECTOR_CRT_B64="$(b64 "$OUT_DIR/vault-injector-crt.crt")"
INJECTOR_KEY_B64="$(b64 "$OUT_DIR/vault-injector-crt.key")"

# --- Создать preconfigure/<PROJECT>/ и готовые YAML ---
PRECONFIGURE_DIR="$VAULT_DIR/$PROJECT"
mkdir -p "$PRECONFIGURE_DIR"

# vault-ca.yaml (ConfigMap)
CA_PEM_INDENTED="$(sed 's/^/    /' "$OUT_DIR/vault-ca.crt")"
cat > "$PRECONFIGURE_DIR/vault-ca.yaml" << VAULT_CA_EOF
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: vault-ca
  namespace: ${NAMESPACE}
data:
  ca.crt: |
${CA_PEM_INDENTED}
VAULT_CA_EOF

# vault-crt.yaml (Secret)
cat > "$PRECONFIGURE_DIR/vault-crt.yaml" << VAULT_CRT_EOF
---
kind: Secret
apiVersion: v1
metadata:
  name: vault-crt
  namespace: ${NAMESPACE}
data:
  tls.crt: ${VAULT_CRT_B64}
  tls.key: ${VAULT_KEY_B64}
type: kubernetes.io/tls
VAULT_CRT_EOF

# vault-injector-crt.yaml (Secret)
cat > "$PRECONFIGURE_DIR/vault-injector-crt.yaml" << VAULT_INJ_EOF
---
kind: Secret
apiVersion: v1
metadata:
  name: vault-injector-crt
  namespace: ${NAMESPACE}
data:
  tls.crt: ${INJECTOR_CRT_B64}
  tls.key: ${INJECTOR_KEY_B64}
type: kubernetes.io/tls
VAULT_INJ_EOF

echo ""
echo "=== Сертификаты: $OUT_DIR ==="
echo "  vault-ca.crt, vault-ca.key, vault-crt.crt, vault-crt.key, vault-injector-crt.crt, vault-injector-crt.key, caBundle.b64"
echo ""
echo "=== Созданы манифесты: $PRECONFIGURE_DIR ==="
echo "  vault-ca.yaml, vault-crt.yaml, vault-injector-crt.yaml"
echo ""
echo "=== caBundle для custom-values (injector.certs.caBundle) ==="
echo "  Значение сохранено в: $OUT_DIR/caBundle.b64"
echo "  Вставить в: charts/vault-1.14.0/custom-values/${PROJECT}-vault.yaml"
echo ""
echo "Дальше: вставить содержимое caBundle.b64 в custom-values, затем: kubectl apply -f preconfigure/${PROJECT}/"
