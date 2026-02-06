#!/bin/bash
# Download Talos disk image from factory.talos.dev into fetched/.
# Fetches .qcow2, saves as .img (~210 MB). Requires: curl.
# Run from project root. Upload to Proxmox and set talos_image_file_id in terraform.tfvars.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
cd "$ROOT_DIR"

TALOS_VERSION="${TALOS_VERSION:-1.10.6}"
# default schematic: qemu-guest-agent (see factory.talos.dev)
TALOS_SCHEMATIC_ID="${TALOS_SCHEMATIC_ID:-ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515}"
BASE="https://factory.talos.dev/image/${TALOS_SCHEMATIC_ID}/v${TALOS_VERSION}"
QCOW2="metal-amd64.qcow2"
OUT="fetched/talos-${TALOS_VERSION}-amd64.img"

mkdir -p fetched

if [ -f "${OUT}" ]; then
  echo "Talos image already exists: ${OUT}"
  echo "Upload to Proxmox, set talos_image_file_id in terraform.tfvars, then ./scripts/deploy/start.sh"
  exit 0
fi

echo "Downloading Talos v${TALOS_VERSION} from factory.talos.dev (.qcow2 -> .img, ~210 MB)..."
curl -fL# "${BASE}/${QCOW2}" -o "${OUT}"
echo "Done: ${OUT}"
echo ""
echo "Upload to Proxmox (e.g. Storage -> local -> ISO Images -> Upload), then in terraform.tfvars:"
echo '  talos_image_file_id = "local:iso/talos-'"${TALOS_VERSION}"'-amd64.img"'
echo "Run ./scripts/deploy/start.sh"