# n8n ArgoCD Application

Конфигурация для развертывания n8n через ArgoCD. n8n — инструмент workflow-автоматизации и интеграций (self-hosted альтернатива Zapier/Make)

<details>
<summary><strong>Быстрый старт</strong></summary>

---

1. **cert-manager и ClusterIssuer** должны быть развернуты (см. [03-argocd/README.md](../README.md)).
2. **Применить ArgoCD Application:**
   ```bash
   kubectl apply -f 03-argocd/n8n/n8n.yaml
   ```
3. **Дождаться готовности:**
   ```bash
   kubectl get pods -n n8n -w
   ```
4. **Доступ:** `https://n8n.lab-home.com` (при первом входе — настройка владельца).

</details>

<details>
<summary><strong>Описание и компоненты</strong></summary>

---

- **Deployment** — образ `n8nio/n8n:latest`, порт 5678, переменные `N8N_HOST` / `N8N_PROTOCOL` для работы за Ingress.
- **Service** — ClusterIP, порт 80 → 5678.
- **PersistentVolumeClaim** — `n8n-data` (5Gi) для `/home/node/.n8n` (workflows и учётные данные).
- **Ingress** — TLS через cert-manager, host `n8n.lab-home.com`.
- **Namespace** — `n8n`.

</details>

<details>
<summary><strong>Структура файлов</strong></summary>

---

```
n8n/
├── n8n.yaml              # ArgoCD Application (Kustomize)
├── kustomization.yaml
├── base/
│   ├── namespace.yaml
│   ├── pvc.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
└── README.md
```

</details>

<details>
<summary><strong>Предварительные требования</strong></summary>

---

- Kubernetes 1.23+, ArgoCD, ingress-nginx, StorageClass (например local-path), cert-manager и ClusterIssuer.
- Git-репозиторий настроен в ArgoCD (path `03-argocd/n8n`).
- DNS для `n8n.lab-home.com` (или изменить host в Ingress и переменные в Deployment).

</details>

<details>
<summary><strong>Конфигурация и устранение неполадок</strong></summary>

---

- **Смена домена:** изменить `N8N_HOST` в `base/deployment.yaml` и host/secretName в `base/ingress.yaml`.
- **Certificate не Ready:** убедиться, что cert-manager и ClusterIssuer развернуты до n8n; при необходимости удалить секреты `n8n-tls`, `n8n-tls-ca`, `n8n-tls-chain` в namespace `n8n` для перевыпуска.
- **Поды не стартуют:** проверить `kubectl logs -n n8n deployment/n8n` и `kubectl describe pod -n n8n -l app=n8n`. При использовании `/healthz` для проб убедиться, что версия n8n поддерживает этот endpoint; при необходимости сменить путь пробы на `/`.

</details>
