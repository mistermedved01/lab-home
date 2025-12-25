# Установка ingress-nginx и ArgoCD

Эта директория содержит конфигурацию для установки ingress-nginx и ArgoCD через Helm.

## Структура

```
02-k8s-argocd-install/
├── helm/
│   ├── ingress-nginx/
│   │   ├── values.yaml               # Конфигурация ingress-nginx
│   │   └── install.sh                # Скрипт установки ingress-nginx
│   ├── argocd/
│   │   ├── values.yaml               # Конфигурация ArgoCD
│   │   └── install.sh                # Скрипт установки ArgoCD
│   └── install-all.sh                # Скрипт установки всех компонентов
└── README.md                         # Этот файл
```

**Примечание:** Ansible playbooks находятся в `01-proxmox-terraform-k8s-ansible/live/ansible/playbooks/playbooks/`:
- `ingress-nginx-install.yml`
- `argocd-install.yml`

Values файлы для Ansible находятся в `01-proxmox-terraform-k8s-ansible/live/ansible/playbooks/helm/`

## Предварительные требования

1. Kubernetes кластер должен быть полностью настроен и готов к работе
2. Helm должен быть установлен на control plane ноде
3. Доступ к control plane ноде через SSH
4. `kubectl` настроен для работы с кластером

## Последовательность установки

### Вариант 1: Установка через Ansible (рекомендуется)

Автоматическая установка через Ansible playbooks - наиболее надежный и идемпотентный способ.

**Playbooks находятся в `01-proxmox-terraform-k8s-ansible/live/ansible/playbooks/playbooks/`**

Краткая инструкция:

```bash
# На ansible-control VM
cd /etc/ansible/playbooks
ansible-playbook playbooks/site.yml
```

Или установка по отдельности:

```bash
# Установка только ingress-nginx
ansible-playbook playbooks/ingress-nginx-install.yml

# Установка только ArgoCD
ansible-playbook playbooks/argocd-install.yml
```

**Примечание:** Playbooks автоматически используют values файлы из `01-proxmox-terraform-k8s-ansible/live/ansible/playbooks/helm/`

### Вариант 2: Автоматическая установка через скрипты

#### Установка всех компонентов сразу

```bash
# Подключение к control plane ноде
ssh -i ~/.ssh/id_ed25519 ubuntu@<K8S_CONTROL_IP>

# Копирование директории на сервер (если нужно)
# scp -r -i ~/.ssh/id_ed25519 02-k8s-argocd-install ubuntu@<K8S_CONTROL_IP>:~/

# Переход в директорию
cd ~/02-k8s-argocd-install/helm

# Установка всех компонентов
chmod +x install-all.sh
./install-all.sh
```

#### Установка по отдельности

```bash
# Установка только ingress-nginx
cd ~/02-k8s-argocd-install/helm
chmod +x ingress-nginx/install.sh
./ingress-nginx/install.sh

# Установка только ArgoCD
chmod +x argocd/install.sh
./argocd/install.sh
```

### Вариант 3: Ручная установка через Helm команды

#### 1. Установка ingress-nginx

Ingress-nginx должен быть установлен первым, так как он необходим для ingress ArgoCD.

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
  -f helm/ingress-nginx/values.yaml

# Проверка установки
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

#### 2. Установка ArgoCD

После установки ingress-nginx можно устанавливать ArgoCD.

```bash
# Добавление официального Helm репозитория ArgoCD
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Установка ArgoCD
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  -f helm/argocd/values.yaml

# Ожидание готовности pods
kubectl wait --namespace argocd \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=argocd-server \
  --timeout=300s

# Получение начального пароля администратора
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo
```

## Проверка установки

### Проверка ingress-nginx

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

### Проверка ArgoCD

```bash
kubectl get pods -n argocd
kubectl get svc -n argocd
```

## Доступ к ArgoCD

После установки ArgoCD доступен через:

1. **Port-forward (для тестирования):**
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```
   Затем откройте в браузере: https://localhost:8080

2. **Ingress (если настроен):**
   Откройте в браузере URL, указанный в `helm/argocd/values.yaml` в секции `server.ingress.hosts`

**Логин:** `admin`  
**Пароль:** Используйте пароль, полученный из секрета `argocd-initial-admin-secret`

## Обновление конфигурации

Для обновления конфигурации:

```bash
# Обновление ingress-nginx
helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  -f helm/ingress-nginx/values.yaml

# Обновление ArgoCD
helm upgrade argocd argo/argo-cd \
  --namespace argocd \
  -f helm/argocd/values.yaml
```

## Удаление

```bash
# Удаление ArgoCD
helm uninstall argocd --namespace argocd

# Удаление ingress-nginx
helm uninstall ingress-nginx --namespace ingress-nginx
```

## Дополнительные ресурсы

- [ingress-nginx документация](https://kubernetes.github.io/ingress-nginx/)
- [ArgoCD документация](https://argo-cd.readthedocs.io/)
- [ArgoCD Helm chart](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd)

