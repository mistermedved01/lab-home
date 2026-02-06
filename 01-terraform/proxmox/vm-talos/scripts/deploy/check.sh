#!/bin/bash

# Скрипт проверки работоспособности Talos кластера и Flannel CNI

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
cd "$ROOT_DIR"

get_tfvars_var() {
  grep -E "^\s*${1}\s*=" terraform.tfvars 2>/dev/null | sed -E 's/.*=\s*"([^"]+)".*/\1/' | head -1 | tr -d ' \r'
}

if [ -z "${TALOS_CLUSTER_NAME:-}" ] && [ -f terraform.tfvars ]; then
  TALOS_CLUSTER_NAME=$(get_tfvars_var talos_cluster_name)
fi
TALOS_CLUSTER_NAME="${TALOS_CLUSTER_NAME:-talos-cluster-01}"

KUBECONFIG_FILE=~/.kube/${TALOS_CLUSTER_NAME}.yaml

echo "=========================================="
echo "Проверка Talos Kubernetes кластера"
echo "=========================================="
echo ""

# Проверка наличия kubeconfig
if [ ! -f "${KUBECONFIG_FILE}" ]; then
    echo " Kubeconfig не найден: ${KUBECONFIG_FILE}"
    echo "   Запустите: terraform output -raw kubeconfig > ${KUBECONFIG_FILE}"
    exit 1
fi

echo "OK: Kubeconfig найден: ${KUBECONFIG_FILE}"
echo ""

# Проверка подключения к кластеру
echo "1. Проверка подключения к кластеру..."
if kubectl --kubeconfig ${KUBECONFIG_FILE} cluster-info &>/dev/null; then
    echo "OK: Подключение к кластеру успешно"
    kubectl --kubeconfig ${KUBECONFIG_FILE} cluster-info | head -1
else
    echo " Не удалось подключиться к кластеру"
    exit 1
fi
echo ""

# Проверка нод
echo "2. Проверка нод кластера..."
NODES=$(kubectl --kubeconfig ${KUBECONFIG_FILE} get nodes --no-headers 2>/dev/null | wc -l)
if [ "$NODES" -gt 0 ]; then
    echo "OK: Найдено нод: $NODES"
    kubectl --kubeconfig ${KUBECONFIG_FILE} get nodes -o wide
else
    echo " Ноды не найдены"
    exit 1
fi
echo ""

# Проверка статуса нод
echo "3. Статус нод..."
READY_NODES=$(kubectl --kubeconfig ${KUBECONFIG_FILE} get nodes --no-headers 2>/dev/null | grep -c " Ready " || echo "0")
NOT_READY_NODES=$(kubectl --kubeconfig ${KUBECONFIG_FILE} get nodes --no-headers 2>/dev/null | grep -v " Ready " | wc -l)

if [ "$READY_NODES" -gt 0 ]; then
    echo "OK: Готовых нод: $READY_NODES"
else
    echo " Нет готовых нод"
fi

if [ "$NOT_READY_NODES" -gt 0 ]; then
    echo "WARN: Нод не готово: $NOT_READY_NODES"
    kubectl --kubeconfig ${KUBECONFIG_FILE} get nodes | grep -v " Ready "
fi
echo ""

# Проверка Flannel CNI
echo "4. Проверка Flannel CNI..."
FLANNEL_PODS=$(kubectl --kubeconfig ${KUBECONFIG_FILE} get pods -n kube-system --no-headers 2>/dev/null | grep -c kube-flannel || echo "0")
FLANNEL_READY=$(kubectl --kubeconfig ${KUBECONFIG_FILE} get pods -n kube-system --no-headers 2>/dev/null | grep kube-flannel | grep -c " Running " || echo "0")
CNI_PODS=$FLANNEL_PODS
CNI_READY=$FLANNEL_READY

if [ "$FLANNEL_PODS" -gt 0 ]; then
    echo "OK: Найдено Flannel подов: $FLANNEL_PODS"
    if [ "$FLANNEL_READY" -eq "$FLANNEL_PODS" ]; then
        echo "OK: Все Flannel поды работают ($FLANNEL_READY/$FLANNEL_PODS)"
    else
        echo "WARN: Не все Flannel поды готовы ($FLANNEL_READY/$FLANNEL_PODS)"
        kubectl --kubeconfig ${KUBECONFIG_FILE} get pods -n kube-system | grep flannel
    fi
else
    echo " Flannel поды не найдены (устанавливаются Talos при bootstrap)"
fi
echo ""

# Проверка системных подов
echo "5. Проверка системных подов..."
SYSTEM_PODS=$(kubectl --kubeconfig ${KUBECONFIG_FILE} get pods -n kube-system --no-headers 2>/dev/null | wc -l)
SYSTEM_READY=$(kubectl --kubeconfig ${KUBECONFIG_FILE} get pods -n kube-system --no-headers 2>/dev/null | grep -c " Running " || echo "0")

if [ "$SYSTEM_PODS" -gt 0 ]; then
    echo "OK: Системных подов: $SYSTEM_PODS (готово: $SYSTEM_READY)"
    NOT_READY_SYSTEM=$(kubectl --kubeconfig ${KUBECONFIG_FILE} get pods -n kube-system --no-headers 2>/dev/null | grep -v " Running ")
    if [ -n "$NOT_READY_SYSTEM" ]; then
        echo "WARN: Не готовые системные поды:"
        echo "$NOT_READY_SYSTEM" | head -5
    fi
else
    echo "FAIL: Системные поды не найдены"
fi
echo ""

# Итоговая сводка
echo "=========================================="
echo "Итоговая сводка"
echo "=========================================="

ALL_OK=true

if [ "$READY_NODES" -eq 0 ]; then
    echo "FAIL: Нет готовых нод"
    ALL_OK=false
fi

if [ "$CNI_PODS" -eq 0 ]; then
    echo "FAIL: Flannel не установлен"
    ALL_OK=false
elif [ "$CNI_READY" -ne "$CNI_PODS" ]; then
    echo "WARN: Flannel не полностью готов"
fi

if [ "$ALL_OK" = true ] && [ "$CNI_READY" -eq "$CNI_PODS" ]; then
    echo ""
    echo "OK: Кластер работает корректно!"
    echo ""
    echo "Полезные команды:"
    echo "  kubectl --kubeconfig ${KUBECONFIG_FILE} get nodes"
    echo "  kubectl --kubeconfig ${KUBECONFIG_FILE} get pods -A"
    echo "  kubectl --kubeconfig ${KUBECONFIG_FILE} get pods -n kube-system | grep flannel"
else
    echo ""
    echo "WARN: Обнаружены проблемы. Проверьте вывод выше."
    exit 1
fi
