# Rancher

`Rancher` - веб-платформа для управления Kubernetes-кластерами и приложениями.
TLS для `Ingress` выпускается внешним `cert-manager` через `ClusterIssuer`.

<details>
<summary><strong>⚙️Установка</strong></summary>

---

Порядок важен: сначала StorageClass, затем cert-manager и `ClusterIssuer`, после этого Rancher.

### 1) StorageClass - local-path (`03-argocd/local-path-provisioner`)

```bash
helm upgrade --install local-path-provisioner ./03-argocd/local-path-provisioner/helm/charts/local-path-provisioner \
  -n local-path-storage \
  --create-namespace \
  -f ./03-argocd/local-path-provisioner/helm/custom-values/lab-home.yaml

kubectl get storageclass
```

### 2) cert-manager (`03-argocd/cert-manager`)

```bash
kubectl apply -f 03-argocd/cert-manager/application.yaml
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s
```

### 3) ClusterIssuer (`03-argocd/cert-manager/clusterissuer-selfsigned.yaml`)

```bash
kubectl apply -f 03-argocd/cert-manager/clusterissuer-selfsigned.yaml
kubectl get clusterissuer selfsigned-issuer
```

### 4) Rancher (`03-argocd/rancher/application.yaml`)

```bash
kubectl apply -f 03-argocd/rancher/application.yaml
kubectl get application rancher -n argocd
kubectl get pods -n cattle-system
```

</details>

<details>
<summary><strong>🔍Доступ</strong></summary>

---

- URL: `https://rancher.lab-home.com`
- Username: `admin`
- Начальный пароль:

```bash
kubectl get secret -n cattle-system bootstrap-secret -o jsonpath='{.data.bootstrapPassword}' | base64 -d ; echo
```

При self-signed сертификате браузер покажет предупреждение безопасности.

</details>

<details>
<summary><strong>📋Структура файлов</strong></summary>

---

```text
03-argocd/rancher/
├── application.yaml
├── README.md
└── helm/
    ├── charts/
    │   └── rancher-2.13.0/
    └── custom-values/
        └── lab-home.yaml
```

</details>

<details>
<summary><strong>🔧Частые проблемы</strong></summary>

---

**Pod'ы не становятся Ready**

```bash
kubectl get events -n cattle-system --sort-by='.lastTimestamp'
kubectl logs -n cattle-system deployment/rancher
```

**Ingress/TLS не работает**

```bash
kubectl get ingress -n cattle-system
kubectl describe ingress rancher -n cattle-system
kubectl get certificate -n cattle-system
kubectl describe certificate -n cattle-system
```

**Rancher Application не синхронизируется**

```bash
kubectl get application rancher -n argocd -o yaml
```

</details>

<details>
<summary><strong>⚠️Важные замечания</strong></summary>

---

- Без готового `cert-manager` и `ClusterIssuer` Rancher может подняться без рабочего TLS.
- В `helm/custom-values/lab-home.yaml` задан `hostname: rancher.lab-home.com`; DNS должен резолвиться на ingress-controller.
- Чарт вендорится локально: обновляйте его осознанно и синхронно с `application.yaml`.

</details>