# Velero

Velero выполняет резервное копирование и восстановление ресурсов Kubernetes: Namespace, Deployment, ConfigMap, Secret, PVC и других объектов. Резервные копии хранятся в объектном хранилище MinIO.

Схема:

- Velero (Helm) + plugin AWS (`velero-plugin-for-aws`)
- Object storage — MinIO S3 (`minio-tenant-hl…:9000`)
- Node Agent — file-level backup томов (`defaultVolumesToFsBackup: true`)
- CSI volume snapshots — **выключены**
- Secret с S3-кредами — `kubectl` (не Argo)

| Параметр | Значение |
| --- | --- |
| Namespace | `velero` |
| Chart | `helm/charts/velero-8.6.0` (app `1.15.2`) |
| S3 endpoint | `https://minio-tenant-hl.minio-operator.svc.cluster.local:9000` |
| BSL `default` | bucket `velero-backup` |
| BSL `dev` | bucket `data-backup-dev` (restore) |
| Credentials | Secret `velero-cloud-credentials` (ключ `cloud`) |
| Node Agent | включён |
| Snapshots | `snapshotsEnabled: false` |
| TLS к MinIO | `insecureSkipTLSVerify: "true"` (self-signed lab) |

Argo синкает **только Helm**. Secret `velero-cloud-credentials` **не** входит в Application — его нет в кластере, пока не примените вручную.

## Предварительные требования

1. MinIO Tenant (Operator + Tenant)
2. Bucket **`velero-backup`** в MinIO (для default BSL)
3. Access Key / Secret Key с доступом к bucket’ам Velero
4. (опционально) bucket `data-backup-dev` — если нужна локация `dev`

## Структура

```text
velero/
├── application.yaml
├── manifests/
│   ├── velero-cloud-credentials-secret.example.yaml  # kubectl (не Argo)
│   └── velero-cloud-credentials-secret.yaml          # gitignored
├── helm/
│   ├── charts/velero-8.6.0/
│   └── custom-values/lab-home.yaml
└── README.md
```

## Развёртывание

### 1) Bucket в MinIO

В MinIO Console создать bucket `velero-backup` (или поменять имя в `helm/custom-values/lab-home.yaml`).

### 2) Secret с S3-кредами

Формат ключа `cloud` — AWS credentials:

```ini
[default]
aws_access_key_id=<ACCESS_KEY>
aws_secret_access_key=<SECRET_KEY>
```

```bash
kubectl create namespace velero --dry-run=client -o yaml | kubectl apply -f -

cp 03-argocd/velero/manifests/velero-cloud-credentials-secret.example.yaml \
   03-argocd/velero/manifests/velero-cloud-credentials-secret.yaml
# вписать ACCESS_KEY / SECRET_KEY, затем:
kubectl apply -f 03-argocd/velero/manifests/velero-cloud-credentials-secret.yaml
```

Файл с реальными ключами в `.gitignore`, не коммитить.

Без файла в репо:

```bash
cat > /tmp/credentials-velero <<'EOF'
[default]
aws_access_key_id=ВАШ_ACCESS_KEY
aws_secret_access_key=ВАШ_SECRET_KEY
EOF

kubectl create secret generic velero-cloud-credentials \
  --namespace velero \
  --from-file=cloud=/tmp/credentials-velero
rm -f /tmp/credentials-velero
```

### 3) ArgoCD Application

```bash
kubectl apply -f 03-argocd/velero/application.yaml
kubectl -n argocd get application velero
kubectl get pods,backupstoragelocation -n velero
```

Дождаться Running у `velero-…` и Node Agent DaemonSet, Ready у BackupStorageLocation `default`.

## BackupStorageLocation

| Name | Bucket | Default |
| --- | --- | --- |
| `default` | `velero-backup` | да |
| `dev` | `data-backup-dev` | нет |

Обе смотрят на один MinIO endpoint и один Secret `velero-cloud-credentials`.

## Schedule

После установки, например ежедневный бэкап в 02:00:

```bash
velero schedule create daily-backup --schedule="0 2 * * *" --ttl=72h0m0s
```

Или манифестом:

```yaml
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-backup
  namespace: velero
spec:
  schedule: "0 2 * * *"
  template:
    ttl: 72h
```

Schedule в Application **не** зашит — создаётся вручную при необходимости.

## Проверка

```bash
kubectl get pods -n velero
kubectl get backupstoragelocation -n velero
kubectl get secret velero-cloud-credentials -n velero
```

CLI локально или из пода (бинарь `/velero`, не в PATH). При self-signed MinIO для команд к object storage добавьте `--insecure-skip-tls-verify`:

```bash
VELERO_POD=$(kubectl get pods -n velero -l name=velero \
  --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')

kubectl exec "$VELERO_POD" -n velero -- /velero version
kubectl exec "$VELERO_POD" -n velero -- /velero backup get
kubectl exec "$VELERO_POD" -n velero -- /velero backup location get
```

## Полезные команды

```bash
# список бэкапов (default)
velero backup get

# разовый бэкап
velero backup create manual-backup-$(date +%Y%m%d)

# описание / логи (с insecure для MinIO lab)
velero backup describe <BACKUP_NAME> --insecure-skip-tls-verify
velero backup logs <BACKUP_NAME> --insecure-skip-tls-verify

# restore
velero restore create --from-backup <BACKUP_NAME>
```

Из локации `dev`:

```bash
velero backup get --storage-location dev
velero restore create --from-backup <BACKUP_NAME> --storage-location dev
```

## Частые проблемы

```bash
# BSL не Available
kubectl describe backupstoragelocation default -n velero
kubectl logs -n velero -l app.kubernetes.io/name=velero

# нет Secret → Velero не достучится до MinIO
kubectl get secret velero-cloud-credentials -n velero

# Node Agent / volume backup
kubectl get ds -n velero
kubectl logs -n velero -l name=node-agent
```

`upgradeCRDs: false` — Job апгрейда CRD отключён (несовместимость образов kubectl/velero). CRD ставятся из chart `crds/` при install.

## Апгрейд chart

Один chart в git: `helm/charts/velero-8.6.0`. Path в `application.yaml`. Перед сменой версии — breaking changes values, совместимость `velero-plugin-for-aws` и CRDs.
