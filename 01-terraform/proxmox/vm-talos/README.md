# Terraform Proxmox Talos Cluster

Развертывание Kubernetes кластера на базе Talos OS в Proxmox VE.

<details>
<summary><strong>🚀Быстрый старт</strong></summary>

---

**Минимальные шаги для развертывания кластера:**

1. **Скопируйте и отредактируйте конфигурацию:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Отредактируйте: proxmox_endpoint, proxmox_username, proxmox_password, talos_cluster_name, talos_image_file_id, control_nodes, worker_nodes
   ```

2. **Скачайте образ Talos и загрузите в Proxmox:**
   ```bash
   ./scripts/fetch/fetch-talos.sh
   # Загрузите fetched/talos-<ver>-amd64.img в Proxmox: Storage → local → ISO Images → Upload
   ```

3. **Скачайте чарты Argo CD и NGINX Ingress (опционально, если планируете ставить):**
   ```bash
   ./scripts/fetch/fetch-argocd.sh
   ./scripts/fetch/fetch-ingress-nginx.sh
   ```

5. **Запустите развертывание:**
   ```bash
   ./scripts/deploy/start.sh
   ```
   Ответьте `y` на Apply, Save kubeconfig. При необходимости — `y` на «Install Argo CD?» и «Install NGINX Ingress Controller?» (нужны чарты из шага 3).

6. **Подключитесь к кластеру:**
   ```bash
   export KUBECONFIG=~/.kube/talos-cluster-01.yaml
   kubectl get nodes
   ```

📋**Детальные инструкции:** см. секции ниже.

</details>

<details>
<summary><strong>📋Описание и архитектура</strong></summary>

---

- **Control Planes:** 1 нода (talos-cp-01)
- **Workers:** 2 ноды (talos-worker-01, talos-worker-02)
- **CNI:** Flannel (встроенный Talos)
- **Talos:** 1.10.6 (образ в Proxmox)

Опционально после развертывания: Argo CD (GitOps), NGINX Ingress Controller (NodePort 30080/30443).

### Что скачивается и что ставится

| Компонент | Скачивается | Ставится |
|-----------|-------------|----------|
| **Talos** | Образ с [factory.talos.dev](https://factory.talos.dev) в `fetched/talos-<ver>-amd64.img` (`./scripts/fetch/fetch-talos.sh`). Дальше образ загружается в Proxmox вручную (Storage → ISO Images). | Terraform создаёт VM в Proxmox с этим образом и применяет конфигурацию Talos (bootstrap, kubeconfig). |
| **Flannel** | — (встроен в Talos) | Talos устанавливает Flannel при bootstrap. Чарты не требуются. |
| **Argo CD** | Helm-чарт в `fetched/argo-cd-<ver>.tgz` (`./scripts/fetch/fetch-argocd.sh`). | Опционально в `start.sh` (ответ «y» на «Install Argo CD?») — Helm в namespace argocd, values из `platform/argocd/values.yaml`. |
| **Ingress NGINX** | Helm-чарт в `fetched/ingress-nginx-<ver>.tgz` (`./scripts/fetch/fetch-ingress-nginx.sh`). | Опционально в `start.sh` (ответ «y» на «Install NGINX Ingress Controller?») — Helm в namespace ingress-nginx, values из `platform/ingress-nginx/values.yaml`. NodePort HTTP 30080, HTTPS 30443. |

</details>

<details>
<summary><strong>📋Структура проекта</strong></summary>

---

```
.
├── main.tf, variables.tf, outputs.tf   # Terraform (образ из Proxmox)
├── terraform.tfvars.example            # Пример переменных
├── scripts/
│   ├── fetch/                          # Скачивание артефактов в fetched/
│   │   ├── fetch-argocd.sh
│   │   ├── fetch-ingress-nginx.sh
│   │   └── fetch-talos.sh
│   └── deploy/                         # Развертывание и эксплуатация
│       ├── start.sh                    # Развертывание кластера
│       ├── destroy.sh                  # Удаление кластера
│       └── check.sh                    # Проверка кластера
├── fetched/                            # argo-cd, ingress-nginx чарты, talos образ (в .gitignore)
├── docs/                               # Доп. документация
│   └── argocd-ingress-nginx.md         # Argo CD за NGINX Ingress (редиректы, TLS)
└── platform/                           # K8s add-ons (Helm values)
    ├── argocd/
    │   └── values.yaml
    └── ingress-nginx/
        └── values.yaml
```

</details>

<details>
<summary><strong>📋Предварительные требования</strong></summary>

---

1. **Terraform >= 1.0, kubectl, helm**
   ```bash
   terraform version
   kubectl version --client
   helm version
   ```

2. **Proxmox VE >= 7.0**, доступ к API (endpoint, username, password в `terraform.tfvars`).

3. **Образ Talos** загружен в Proxmox (например в `local` → ISO Images), в `terraform.tfvars` указан `talos_image_file_id`.

</details>

<details>
<summary><strong>⚙️Установка и скрипты</strong></summary>

---

### Конфигурация

Вся конфигурация — в `terraform.tfvars`. Не коммитьте файл (он в `.gitignore`).

```bash
cp terraform.tfvars.example terraform.tfvars
# Отредактируйте: proxmox_endpoint, proxmox_username, proxmox_password, talos_cluster_name, talos_image_file_id, control_nodes, worker_nodes
```

### fetch-argocd.sh — скачать Argo CD в fetched/

```bash
./scripts/fetch/fetch-argocd.sh
```

Качает чарт Argo CD в `fetched/argo-cd-<ver>.tgz`. При `start.sh` ответьте «y» на «Install Argo CD?».

### fetch-ingress-nginx.sh — скачать NGINX Ingress в fetched/

```bash
./scripts/fetch/fetch-ingress-nginx.sh
```

Качает чарт ingress-nginx. При `start.sh` ответьте «y» на «Install NGINX Ingress Controller?». NodePort HTTP 30080, HTTPS 30443; IngressClass `nginx` по умолчанию.

### fetch-talos.sh — скачать образ Talos в fetched/

```bash
./scripts/fetch/fetch-talos.sh
```

Качает образ с **factory.talos.dev** (~210 MB). Версию: `TALOS_VERSION=1.10.6 ./scripts/fetch/fetch-talos.sh`. Дальше — загрузить в Proxmox и указать `talos_image_file_id` в `terraform.tfvars`.

### start.sh — развернуть кластер

```bash
./scripts/deploy/start.sh
```

Проверяет зависимости (terraform, helm, kubectl) и образ. Terraform plan/apply, сохранение kubeconfig. Flannel устанавливается Talos при bootstrap. Опционально: Argo CD и NGINX Ingress. В конце выводит сводку: IP нод, Argo CD (URL, user admin, пароль).

### destroy.sh — удалить кластер

```bash
./scripts/deploy/destroy.sh
```

`terraform destroy`, удаление kubeconfig из `~/.kube/`.

### check.sh — проверить кластер

Требуется kubeconfig в `~/.kube/<talos_cluster_name>.yaml` (сохраняется при «Save kubeconfig?» в `start.sh` или вручную: `terraform output -raw kubeconfig > ~/.kube/talos-cluster-01.yaml`).

Проверяет ноды, Flannel CNI и системные поды.

```bash
./scripts/deploy/check.sh
```

</details>

<details>
<summary><strong>🔍Доступ к кластеру и компонентам</strong></summary>

---

### Подключение к кластеру

Имя кластера — из `talos_cluster_name` в `terraform.tfvars` (например `talos-cluster-01`).

```bash
export KUBECONFIG=~/.kube/talos-cluster-01.yaml
kubectl get nodes
```

### Argo CD (если установлен)

- **Доступ по сети:** https://argocd.lab-home.com:30443/ (логин: admin) — через NGINX Ingress (HTTPS NodePort 30443). Убедитесь, что `argocd.lab-home.com` указывает на IP одной из нод (DNS или `/etc/hosts`).
- **Пароль admin:** после `start.sh` пароль выводится в сводке; иначе: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`
- **Port-forward:** `kubectl -n argocd port-forward svc/argocd-server 8080:443` → https://localhost:8080
- При редиректах или ошибке «plain HTTP request to HTTPS port» см. [docs/argocd-ingress-nginx.md](docs/argocd-ingress-nginx.md).

Сервер Argo CD по умолчанию использует самоподписанный сертификат — браузер может показать предупреждение, его можно принять.

### Приложения из 03-argocd (GitOps)

Приложения из общего каталога репозитория **03-argocd** (cert-manager, n8n, minio, homepage и др.) в вариант Talos не копируются Terraform — они подтягиваются **Argo CD из Git** (GitOps).

1. В Argo CD создайте **Application** с источником: репозиторий lab-home (URL этого репо) и путь к приложению, например:
   - `03-argocd/n8n` — развернуть только n8n;
   - `03-argocd/cert-manager` — только cert-manager (обычно первым для TLS);
   - или несколько Application на разные подкаталоги `03-argocd/<имя>`.
2. Argo CD будет синхронизировать состояние из Git; можно включать и отключать приложения по одному, создавая или удаляя соответствующие Application.

Подробнее о манифестах приложений: [03-argocd/README.md](../../../03-argocd/README.md) в корне репозитория.

### NGINX Ingress Controller (если установлен)

- **Порты:** HTTP — 30080, HTTPS — 30443 (NodePort на любой ноде). IngressClass `nginx` задана по умолчанию.
- **Пример Ingress** для приложения:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
spec:
  ingressClassName: nginx
  rules:
    - host: myapp.lab-home.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 80
```

Доступ: http://myapp.lab-home.com:30080 или https://myapp.lab-home.com:30443 (DNS/hosts должен указывать на IP ноды).

</details>

<details>
<summary><strong>🔧Устранение неполадок</strong></summary>

---

### Kubelet Unhealthy / ноды NotReady

**Причина:** чаще всего CNI (Flannel) не установлен или не готов.

**Решение:**
```bash
kubectl get pods -n kube-system | grep flannel
# Flannel устанавливается Talos при bootstrap. Дождитесь Running подов kube-flannel
kubectl get nodes
```

### Kubeconfig не найден

```bash
terraform output -raw kubeconfig > ~/.kube/talos-cluster-01.yaml
# Подставьте имя кластера из talos_cluster_name в terraform.tfvars
```

</details>

<details>
<summary><strong>⚠️Важные замечания</strong></summary>

---

- **terraform.tfvars** не коммитьте (учётные данные Proxmox, пароли).
- **fetched/** в `.gitignore` — чарты и образ Talos скачиваются локально.
- Имя кластера и путь к kubeconfig: `~/.kube/<talos_cluster_name>.yaml`.

</details>