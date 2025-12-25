#!/bin/bash
set -e

echo "=========================================="
echo "Установка ArgoCD"
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

echo "Добавление Helm репозитория ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm || true
helm repo update

echo "Установка ArgoCD..."
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  -f "$VALUES_FILE"

echo "Ожидание готовности ArgoCD pods..."
kubectl wait --namespace argocd \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=argocd-server \
  --timeout=300s

echo ""
echo "=========================================="
echo "ArgoCD успешно установлен!"
echo "=========================================="
echo ""
echo "Статус pods:"
kubectl get pods -n argocd
echo ""
echo "Статус сервисов:"
kubectl get svc -n argocd
echo ""

# Получение начального пароля администратора
echo "Получение начального пароля администратора..."
ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "Секрет еще не создан, подождите несколько секунд и выполните:")
if [ -n "$ADMIN_PASSWORD" ] && [ "$ADMIN_PASSWORD" != "Секрет еще не создан, подождите несколько секунд и выполните:" ]; then
    echo ""
    echo "=========================================="
    echo "Данные для входа в ArgoCD:"
    echo "=========================================="
    echo "Логин: admin"
    echo "Пароль: $ADMIN_PASSWORD"
    echo ""
    echo "Для доступа через port-forward:"
    echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "  Затем откройте: https://localhost:8080"
    echo "=========================================="
else
    echo ""
    echo "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
    echo ""
fi

