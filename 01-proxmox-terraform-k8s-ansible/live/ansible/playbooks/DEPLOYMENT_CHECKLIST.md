# Чеклист для переразвертывания через Ansible ✅

## Статус готовности

✅ **Все файлы обновлены и синхронизированы:**
- `helm/argocd/values.yaml` - настроен insecure режим и HTTP ingress
- `helm/ingress-nginx/values.yaml` - включен SSL passthrough
- Файлы скопированы на сервер ansible (`/etc/ansible/playbooks/`)

## Что будет работать при переразвертывании

### 1. Kubernetes установка
- ✅ `common-setup.yml` - установка containerd, kubelet, kubeadm, kubectl
- ✅ `k8s-control-setup.yml` - инициализация control plane
- ✅ `cni-setup.yml` - установка Flannel CNI
- ✅ `k8s-worker-setup.yml` - подключение worker нод

### 2. Helm и Ingress
- ✅ `helm-install.yml` - установка Helm
- ✅ `ingress-nginx-install.yml` - установка ingress-nginx с NodePort (30080/30443)
- ✅ `argocd-install.yml` - установка ArgoCD с настроенным ingress

### 3. ArgoCD конфигурация
- ✅ Ingress настроен на `argocd.example.com`
- ✅ HTTP режим (insecure) для работы через ingress
- ✅ Backend protocol: HTTP
- ✅ SSL redirect отключен

## После переразвертывания

1. **Добавьте в hosts файл:**
   ```
   192.168.40.145 argocd.example.com
   ```

2. **Откройте в браузере:**
   ```
   http://argocd.example.com:30080
   ```

3. **Войдите:**
   - Логин: `admin`
   - Пароль: получите через:
     ```bash
     kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
     ```

## Важные замечания

⚠️ **При полном переразвертывании:**
- Все данные в кластере будут удалены
- ArgoCD пароль будет сгенерирован заново
- Приложения, развернутые через ArgoCD, нужно будет развернуть заново

✅ **Идемпотентность:**
- Playbooks идемпотентны - можно запускать несколько раз
- Если компоненты уже установлены, они будут обновлены, а не переустановлены

## Проверка после развертывания

```bash
# Проверка кластера
kubectl get nodes

# Проверка ingress-nginx
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

# Проверка ArgoCD
kubectl get pods -n argocd
kubectl get ingress -n argocd

# Проверка конфигурации ArgoCD
kubectl get configmap argocd-cmd-params-cm -n argocd -o yaml | grep insecure
```

## Команда для полного переразвертывания

```bash
# На сервере ansible (192.168.40.144)
cd /etc/ansible/playbooks
ansible-playbook -i /etc/ansible/inventory.yaml site.yml
```

Или по шагам:
```bash
ansible-playbook -i /etc/ansible/inventory.yaml playbooks/common-setup.yml
ansible-playbook -i /etc/ansible/inventory.yaml playbooks/k8s-control-setup.yml
ansible-playbook -i /etc/ansible/inventory.yaml playbooks/cni-setup.yml
ansible-playbook -i /etc/ansible/inventory.yaml playbooks/k8s-worker-setup.yml
ansible-playbook -i /etc/ansible/inventory.yaml playbooks/helm-install.yml
ansible-playbook -i /etc/ansible/inventory.yaml playbooks/ingress-nginx-install.yml
ansible-playbook -i /etc/ansible/inventory.yaml playbooks/argocd-install.yml
```

