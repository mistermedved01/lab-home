#!/bin/bash
set -e

echo "=========================================="
echo "Установка ingress-nginx и ArgoCD"
echo "=========================================="

# Получение директории скрипта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Установка ingress-nginx
echo ""
echo "Шаг 1: Установка ingress-nginx..."
echo ""
bash "${SCRIPT_DIR}/ingress-nginx/install.sh"

# Небольшая пауза между установками
sleep 5

# Установка ArgoCD
echo ""
echo "Шаг 2: Установка ArgoCD..."
echo ""
bash "${SCRIPT_DIR}/argocd/install.sh"

echo ""
echo "=========================================="
echo "Все компоненты успешно установлены!"
echo "=========================================="

