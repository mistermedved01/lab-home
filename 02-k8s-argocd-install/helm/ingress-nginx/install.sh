#!/bin/bash
set -e

echo "=========================================="
echo "Установка ingress-nginx"
echo "=========================================="

# Проверка наличия Helm
if ! command -v helm &> /dev/null; then
    echo "Ошибка: Helm не установлен. Установите Helm сначала."
    exit 1
fi

# Проверка наличия kubectl
if ! command -v kubectl &> /dev/null; then
    echo "Ошибка: kubectl не установлен. Установите kubectl сначала."
    exit 1
fi

# Получение директории скрипта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES_FILE="${SCRIPT_DIR}/values.yaml"

# Проверка наличия values файла
if [ ! -f "$VALUES_FILE" ]; then
    echo "Ошибка: Файл values.yaml не найден в ${SCRIPT_DIR}"
    exit 1
fi

echo "Добавление Helm репозитория ingress-nginx..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx || true
helm repo update

echo "Установка ingress-nginx-controller..."
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  -f "$VALUES_FILE"

echo "Ожидание готовности ingress-nginx pods..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

echo ""
echo "=========================================="
echo "ingress-nginx успешно установлен!"
echo "=========================================="
echo ""
echo "Статус pods:"
kubectl get pods -n ingress-nginx
echo ""
echo "Статус сервисов:"
kubectl get svc -n ingress-nginx
echo ""

