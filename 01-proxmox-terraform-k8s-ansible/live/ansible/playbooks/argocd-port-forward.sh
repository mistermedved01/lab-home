#!/bin/bash
# Скрипт для быстрого доступа к ArgoCD через port-forward

KUBECONFIG="/home/ubuntu/.kube/config"
NAMESPACE="argocd"
SERVICE="argocd-server"
LOCAL_PORT="8080"
REMOTE_PORT="443"

echo "=========================================="
echo "Запуск port-forward для ArgoCD"
echo "=========================================="
echo "Локальный порт: $LOCAL_PORT"
echo "Удаленный сервис: $SERVICE:$REMOTE_PORT"
echo ""
echo "После запуска откройте в браузере:"
echo "  https://localhost:$LOCAL_PORT"
echo ""
echo "Логин: admin"
echo "Пароль: OcFjE0LhJncpUqJg"
echo ""
echo "Для остановки нажмите Ctrl+C"
echo "=========================================="
echo ""

kubectl port-forward svc/$SERVICE -n $NAMESPACE $LOCAL_PORT:$REMOTE_PORT --kubeconfig=$KUBECONFIG

