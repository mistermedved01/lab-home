# Local Path Provisioner

Local Path Provisioner - простой dynamic provisioner для локальных томов Kubernetes.
По умолчанию используется StorageClass `local-path`

<details>
<summary><strong>⚙️Установка</strong></summary>

---

```bash
helm upgrade --install local-path-provisioner ./03-argocd/local-path-provisioner/helm/charts/local-path-provisioner \
  -n local-path-storage \
  --create-namespace \
  -f ./03-argocd/local-path-provisioner/helm/custom-values/lab-home.yaml
```

</details>

<details>
<summary><strong>📋Структура файлов</strong></summary>

---

```text
03-argocd/local-path-provisioner/
├── README.md
└── helm/
    ├── charts/
    │   └── local-path-provisioner/    # Локальная копия Helm chart
    └── custom-values/
        └── lab-home.yaml              # Значения для lab-home
```

</details>

<details>
<summary><strong>🔍Проверка</strong></summary>

---

```bash
kubectl get pods -n local-path-storage
kubectl get storageclass
```

</details>