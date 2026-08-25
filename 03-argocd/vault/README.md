# Vault

Vault — система централизованного хранения и управления секретами: паролями, токенами, ключами и сертификатами. Обеспечивает безопасный доступ к секретам, разграничение прав и их автоматическую выдачу приложениям и сервисам.

Схема:

- HashiCorp Vault (Helm) — Raft storage, **1 реплика**
- TLS server + injector — cert-manager Certificates (`lab-home-ca-issuer`)
- Agent Injector — MutatingWebhook
- UI — Ingress `https://vault.lab-home.com`
- Опционально: Raft snapshot CronJob → MinIO bucket `vault-backup`

| | |
|---|---|
| Namespace | `vault` |
| Raft | `replicas: 1` |
| Storage | SC: `topolvm-provisioner` \| PVC: `data-vault-0` - 1Gi, `audit-vault-0` - 1Gi |
| TLS / Ingress | cert-manager (`lab-home-ca-issuer`), Secret `vault-ingress-tls` |
| UI | <https://vault.lab-home.com> |
| Chart (active) | `helm/charts/vault-1.14.0` |
| Chart (spare) | `helm/charts/vault-1.21.2` |

## Предварительные требования

1. cert-manager + ClusterIssuer `lab-home-ca-issuer`
2. ingress-nginx
3. Для бэкапа (опционально): MinIO Tenant + bucket **`vault-backup`**

## Структура

```
vault/
├── application.yaml
├── .gitignore
├── manifests/
│   ├── kustomization.yaml              # ← Argo: только TLS
│   ├── vault-tls.yaml
│   ├── vault-injector-tls.yaml
│   ├── configmaps/
│   │   └── vault-backup-configmap.yaml # kubectl (опционально)
│   ├── cronjobs/
│   │   └── vault-backup-cronjob.yaml   # kubectl (опционально)
│   └── secrets/                        # kubectl (опционально)
│       └── example/                    # шаблоны в git; копии рядом — gitignored
├── helm/
│   ├── charts/
│   │   ├── vault-1.14.0/
│   │   └── vault-1.21.2/
│   └── custom-values/lab-home.yaml
└── README.md
```

## Развёртывание

```bash
kubectl apply -f 03-argocd/vault/application.yaml
kubectl -n argocd get application vault
kubectl get certificate,pods,pvc,ingress -n vault
```

Дождаться Ready у `vault-tls` / `vault-injector-tls` и Running у `vault-0` (ещё sealed).

Init + unseal (один раз, ключи сохранить вне git):

```bash
kubectl exec -it vault-0 -n vault -- vault operator init -key-shares=1 -key-threshold=1
kubectl exec -it vault-0 -n vault -- vault operator unseal '<Unseal Key>'
kubectl exec -it vault-0 -n vault -- vault status
```

После рестарта пода Vault снова sealed — повторить unseal.

Argo синкает **только TLS** из `manifests/kustomization.yaml`. ConfigMap, CronJob и secrets бэкапа **не** входят в Application — их нет в кластере, пока не включите вручную.

## Бэкап (опционально)

Работает с `server.ha.replicas: 1`. Knobs: ConfigMap `vault-backup-configmap`. Расписание: `schedule` в CronJob (`0 1 * * *`).

### 1) Bucket и секреты

```bash
# В MinIO создать bucket vault-backup

cp 03-argocd/vault/manifests/secrets/example/minio-s3-ca.yaml \
   03-argocd/vault/manifests/secrets/minio-s3-ca.yaml
cp 03-argocd/vault/manifests/secrets/example/vault-backup-s3-creds.yaml \
   03-argocd/vault/manifests/secrets/vault-backup-s3-creds.yaml
# заполнить PEM CA MinIO и S3 keys, затем:
kubectl apply -f 03-argocd/vault/manifests/secrets/minio-s3-ca.yaml
kubectl apply -f 03-argocd/vault/manifests/secrets/vault-backup-s3-creds.yaml
```

### 2) AppRole snapshot-agent

Vault должен быть unsealed. В поде уже задан `VAULT_CACERT`:

```bash
kubectl exec -it vault-0 -n vault -- sh
vault login   # root token
echo 'path "sys/storage/raft/snapshot" { capabilities = ["read"] }' | vault policy write snapshot -
vault auth enable approle
vault write auth/approle/role/snapshot-agent token_ttl=2h token_policies=snapshot
vault read auth/approle/role/snapshot-agent/role-id
vault write -f auth/approle/role/snapshot-agent/secret-id
```

```bash
cp 03-argocd/vault/manifests/secrets/example/vault-backup-agent-snapshot-token.yaml \
   03-argocd/vault/manifests/secrets/vault-backup-agent-snapshot-token.yaml
# вписать ROLE_ID / SECRET_ID, затем:
kubectl apply -f 03-argocd/vault/manifests/secrets/vault-backup-agent-snapshot-token.yaml
```

### 3) ConfigMap + CronJob

```bash
kubectl apply -f 03-argocd/vault/manifests/configmaps/vault-backup-configmap.yaml
kubectl apply -f 03-argocd/vault/manifests/cronjobs/vault-backup-cronjob.yaml
```

### 4) Проверка

```bash
kubectl create job -n vault vault-backup-manual --from=cronjob/vault-backup-cronjob
kubectl logs -n vault job/vault-backup-manual -c snapshot -f
kubectl logs -n vault job/vault-backup-manual -c upload -f
```

## Restore (вручную)

**Осторожно:** `raft snapshot restore` перезаписывает локальные данные Raft. Делать на остановленном/чистом узле или осознанно принимая потерю текущего state.

1. Скачать `.snap` из MinIO (`s3://vault-backup/...`).
2. Скопировать в под (или PVC) Vault.
3. На узле:

```bash
kubectl exec -it vault-0 -n vault -- vault operator raft snapshot restore /path/to/vault-raft.snap
```

4. Unseal при необходимости, проверить `vault status` и данные.

Автоматического Job restore в репо нет.

## Метрики

ServiceMonitor включён. На listener стоит `unauthenticated_metrics_access = true`, чтобы Prometheus мог скрапить без Vault-токена (lab).

## Апгрейд chart (на будущее)

Как у gitlab: оба chart лежат в git, активный задаётся path в Application.

1. В `application.yaml` сменить path на `03-argocd/vault/helm/charts/vault-1.21.2`.
2. Выровнять image tags в `helm/custom-values/lab-home.yaml` (`server.image`, `injector.agentImage`) и в `manifests/cronjobs/vault-backup-cronjob.yaml`.
3. Проверить breaking changes chart values, закоммитить, дождаться sync / unseal при необходимости.
