# Установка ingress-nginx-controller через Helm

После установки Helm через Ansible playbook `helm-install.yml`, ingress-nginx-controller устанавливается вручную через Helm. Ниже представлены различные варианты установки.

## Предварительные требования

1. Helm должен быть установлен на control plane ноде (выполните `helm-install.yml`)
2. Kubernetes кластер должен быть полностью настроен и готов к работе
3. Доступ к control plane ноде через SSH

## Вариант 1: Базовая установка через Helm (рекомендуется)

Самый простой способ - установка с минимальными настройками:

```bash
# Подключение к control plane ноде
ssh -i ~/.ssh/id_ed25519 ubuntu@<K8S_CONTROL_IP>

# Добавление официального Helm репозитория
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Установка ingress-nginx-controller
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer

# Проверка установки
kubectl get pods -n ingress-nginx -w
kubectl get svc -n ingress-nginx
```

**Преимущества:**
- Простота установки
- Минимальная конфигурация
- Подходит для большинства случаев

## Вариант 2: Установка с кастомными параметрами

Для production окружения рекомендуется использовать values файл:

### Создание values файла

Создайте файл `ingress-nginx-values.yaml`:

```yaml
controller:
  # Тип сервиса
  service:
    type: LoadBalancer
    annotations:
      # Для Proxmox/MetalLB (если используется)
      # metallb.universe.tf/address-pool: default
    # Если нужен NodePort вместо LoadBalancer
    # type: NodePort
    # nodePorts:
    #   http: 30080
    #   https: 30443

  # Количество реплик
  replicaCount: 2

  # Ресурсы
  resources:
    requests:
      cpu: 100m
      memory: 90Mi
    limits:
      cpu: 1000m
      memory: 512Mi

  # Настройки для production
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 5
    targetCPUUtilizationPercentage: 80
    targetMemoryUtilizationPercentage: 80

  # Метрики для мониторинга
  metrics:
    enabled: true
    serviceMonitor:
      enabled: false  # Включите, если используете Prometheus Operator

  # Pod Disruption Budget
  podDisruptionBudget:
    enabled: true
    minAvailable: 1
```

### Установка с values файлом

```bash
# Копирование values файла на control plane ноду (если создавали локально)
scp -i ~/.ssh/id_ed25519 ingress-nginx-values.yaml ubuntu@<K8S_CONTROL_IP>:~/

# Подключение к control plane ноде
ssh -i ~/.ssh/id_ed25519 ubuntu@<K8S_CONTROL_IP>

# Установка
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  -f ingress-nginx-values.yaml

# Проверка
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

**Преимущества:**
- Гибкая настройка под ваши требования
- Подходит для production
- Легко обновлять конфигурацию

## Вариант 3: Установка через скрипт

Создайте скрипт для автоматизации установки:

### Создание скрипта `install-ingress-nginx.sh`

```bash
#!/bin/bash
set -e

echo "Добавление Helm репозитория ingress-nginx..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

echo "Установка ingress-nginx-controller..."
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.replicaCount=2 \
  --set controller.autoscaling.enabled=true \
  --set controller.autoscaling.minReplicas=2 \
  --set controller.autoscaling.maxReplicas=5

echo "Ожидание готовности ingress-nginx pods..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

echo ""
echo "=== Статус ingress-nginx ==="
kubectl get pods -n ingress-nginx
echo ""
kubectl get svc -n ingress-nginx
echo ""
echo "Ingress-nginx-controller успешно установлен!"
```

### Использование скрипта

```bash
# Копирование скрипта на control plane ноду
scp -i ~/.ssh/id_ed25519 install-ingress-nginx.sh ubuntu@<K8S_CONTROL_IP>:~/

# Подключение к control plane ноде
ssh -i ~/.ssh/id_ed25519 ubuntu@<K8S_CONTROL_IP>

# Запуск скрипта
chmod +x install-ingress-nginx.sh
./install-ingress-nginx.sh
```

**Преимущества:**
- Автоматизация процесса
- Повторяемость
- Удобно для CI/CD

## Вариант 4: Установка через kubectl (без Helm)

Если по каким-то причинам не хотите использовать Helm:

```bash
# Подключение к control plane ноде
ssh -i ~/.ssh/id_ed25519 ubuntu@<K8S_CONTROL_IP>

# Установка через манифест
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/cloud/deploy.yaml

# Проверка
kubectl get pods -n ingress-nginx
```

**Недостатки:**
- Сложнее управлять и обновлять
- Нет гибкой настройки через values
- Не рекомендуется для production

## Проверка установки

После установки проверьте:

```bash
# Статус pods
kubectl get pods -n ingress-nginx

# Статус сервисов
kubectl get svc -n ingress-nginx

# Логи контроллера
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Проверка ingress класса
kubectl get ingressclass
```

## Получение внешнего IP

Если используется LoadBalancer:

```bash
# Ожидание назначения внешнего IP
kubectl get svc -n ingress-nginx ingress-nginx-controller -w

# Получение IP адреса
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Если используется NodePort:

```bash
# Получение NodePort
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}'
```

## Обновление ingress-nginx-controller

Для обновления через Helm:

```bash
# Обновление репозитория
helm repo update

# Обновление релиза
helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  -f ingress-nginx-values.yaml  # если используете values файл
```

## Удаление ingress-nginx-controller

```bash
# Удаление через Helm
helm uninstall ingress-nginx --namespace ingress-nginx

# Удаление namespace (опционально)
kubectl delete namespace ingress-nginx
```

## Рекомендации

1. **Для тестирования/разработки:** Используйте Вариант 1 (базовая установка)
2. **Для production:** Используйте Вариант 2 (с values файлом) или Вариант 3 (скрипт)
3. **Для автоматизации:** Используйте Вариант 3 (скрипт) или интегрируйте в CI/CD

## Дополнительные ресурсы

- [Официальная документация ingress-nginx](https://kubernetes.github.io/ingress-nginx/)
- [Helm chart ingress-nginx](https://github.com/kubernetes/ingress-nginx/tree/main/charts/ingress-nginx)
- [Примеры конфигурации](https://kubernetes.github.io/ingress-nginx/examples/)

