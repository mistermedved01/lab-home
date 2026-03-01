# Velero (ArgoCD Application)

Каталог содержит ArgoCD Application для развёртывания [Velero](https://velero.io/) в кластере Kubernetes. Velero выполняет резервное копирование и восстановление ресурсов кластера. Бэкапы сохраняются в MinIO (S3-совместимое хранилище).

## Зачем нужен Velero

- **Бэкап всего кластера** — namespaces, Deployments, ConfigMaps, Secrets, PVC и т.д.
- **Восстановление** — перенос в другой кластер или откат после сбоя.
- **Миграции** — перенос приложений между кластерами.
- **Расписание** — автоматические бэкапы по расписанию (Schedule).

## Предварительные требования

1. **MinIO** развёрнут (Operator + Tenant), доступен внутри кластера по адресу `minio-tenant-hl.minio-operator.svc.cluster.local:9000`.
2. **Bucket для Velero** создан в MinIO (например, `velero-backup`).
3. **Учётные данные S3** — Access Key и Secret Key с доступом к этому bucket (можно использовать те же, что для Vault backup, или отдельного пользователя MinIO).

## Быстрый старт

### 1. Создать bucket в MinIO

В MinIO Console создайте bucket с именем `velero-backup` (или измените `configuration.backupStorageLocation[0].bucket` в `helm/custom-values/lab-home.yaml`).

### 2. Создать Secret с кредами для S3

Velero ожидает секрет в формате AWS credentials. В namespace `velero` должен быть Secret с ключом `cloud` и значением в формате:

```ini
[default]
aws_access_key_id=<ACCESS_KEY>
aws_secret_access_key=<SECRET_KEY>
```

**Пример из файла (без коммита в Git):**

```bash
kubectl create namespace velero --dry-run=client -o yaml | kubectl apply -f -

# Файл credentials-velero (не коммитить!)
cat > credentials-velero << 'EOF'
[default]
aws_access_key_id=ВАШ_ACCESS_KEY
aws_secret_access_key=ВАШ_SECRET_KEY
EOF

kubectl create secret generic velero-cloud-credentials \
  --namespace velero \
  --from-file=cloud=credentials-velero
```

### 3. Применить ArgoCD Application

```bash
kubectl apply -f 03-argocd/velero/application.yaml
```

### 4. Проверить развёртывание

```bash
kubectl get pods -n velero
kubectl get backupstoragelocation -n velero
velero backup location get   # если установлен velero CLI
```

## Конфигурация

Values задаются в `helm/custom-values/lab-home.yaml`.

| Параметр | Значение | Описание |
|----------|----------|----------|
| **Хранилище** | MinIO S3 | `minio-tenant-hl.minio-operator.svc.cluster.local:9000` |
| **Bucket** | `velero-backup` | Имя bucket в MinIO |
| **Секрет** | `velero-cloud-credentials` | Secret с ключом `cloud` (AWS-формат) |
| **Node Agent** | включён | Резервное копирование томов (PV) через file-level backup |
| **Volume snapshots** | выключены | Для local-path нет CSI snapshot; используется fs backup |

При использовании self-signed сертификата MinIO задано `insecureSkipTLSVerify: "true"`. Для production при корректном TLS можно убрать эту опцию в custom-values.

## Расписание бэкапов (Schedule)

После установки создайте Schedule, например ежедневный бэкап в 02:00:

```bash
velero schedule create daily-backup --schedule="0 2 * * *" --ttl=72h0m0s
```

Или через манифест:

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

## Полезные команды

```bash
# Список бэкапов
velero backup get

# Разовый бэкап
velero backup create manual-backup-$(date +%Y%m%d)

# Описание бэкапа
velero backup describe <BACKUP_NAME>

# Восстановление из бэкапа
velero restore create --from-backup <BACKUP_NAME>
```

## Структура

```
velero/
├── application.yaml              # ArgoCD Application
├── helm/
│   ├── charts/
│   │   └── velero-8.6.0/         # Helm chart (vmware-tanzu/velero)
│   └── custom-values/
│       └── lab-home.yaml         # Values для MinIO S3
└── README.md
```

## Ссылки

- [Velero Documentation](https://velero.io/docs/)
- [Velero Helm Chart](https://github.com/vmware-tanzu/helm-charts/tree/main/charts/velero)
- [Velero Plugin for AWS](https://github.com/vmware-tanzu/velero-plugin-for-aws) (S3/MinIO)
