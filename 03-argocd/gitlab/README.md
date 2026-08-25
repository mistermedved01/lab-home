# GitLab

GitLab — платформа Git + CI/CD. В lab — облегчённый chart: webservice, sidekiq, gitaly, shell, встроенные PostgreSQL и Redis. Object store и бэкапы — во внешний MinIO. Runner и tokens exporter — отдельные Applications.

Схема:

- GitLab Helm chart **9.7.1** (spare: `7.11.0`)
- Object store (LFS, artifacts, uploads, packages, …) → MinIO
- Toolbox CronJob бэкапов → MinIO (`0 2 * * *`, `--skip artifacts`)
- Ingress `https://gitlab.lab-home.com` — cert-manager (`lab-home-ca-issuer`)
- Runner — [`../gitlab-runner/`](../gitlab-runner/README.md) (`project/`, `qwe/`)

| Параметр | Значение |
| --- | --- |
| Namespace | `gitlab` |
| URL | <https://gitlab.lab-home.com> |
| TLS / Ingress | cert-manager (`lab-home-ca-issuer`), Secret `gitlab-wildcard-tls` |
| Chart (active) | `helm/charts/gitlab-9.7.1` |
| Chart (spare) | `helm/charts/gitlab-7.11.0` |
| Storage | SC: `topolvm-provisioner` |
| PVC | gitaly 5Gi, postgresql 10Gi, redis 2Gi, toolbox-backup 2Gi |
| S3 Secret | `gitlab-s3-cfg` (ключи `connection`, `s3cmd`) — kubectl |
| Root password | Secret `gitlab-gitlab-initial-root-password` |
| Replicas | webservice / sidekiq / gitaly / shell: `1` |

Argo синкает **только Helm**. Secret `gitlab-s3-cfg` и опциональный Certificate из `manifests/` **не** входят в Application.

## Предварительные требования

1. cert-manager + ClusterIssuer `lab-home-ca-issuer`
2. ingress-nginx
3. StorageClass `topolvm-provisioner`
4. MinIO Tenant + бакеты object store / backups (см. ниже)
5. Ресурсы: ориентир ~1.5 CPU / ~3–4 Gi RAM на GitLab

## Структура

```text
gitlab/
├── application.yaml
├── .gitignore
├── manifests/                              # kubectl (не Argo)
│   ├── certificate.yaml                    # опционально, rotationPolicy
│   ├── gitlab-s3-cfg.example.yaml
│   ├── gitlab-s3-cfg.yaml                  # gitignored
│   └── gitlab-s3-cfg-backup.example.yaml   # опционально, prod-style backup
├── helm/
│   ├── charts/
│   │   ├── gitlab-7.11.0/
│   │   └── gitlab-9.7.1/
│   └── custom-values/lab-home.yaml
└── README.md
```

## Развёртывание

```bash
# 1) namespace + S3 Secret (не в Argo)
kubectl create namespace gitlab --dry-run=client -o yaml | kubectl apply -f -

cp 03-argocd/gitlab/manifests/gitlab-s3-cfg.example.yaml \
   03-argocd/gitlab/manifests/gitlab-s3-cfg.yaml
# заполнить ACCESS_KEY / SECRET_KEY MinIO, затем:
kubectl apply -f 03-argocd/gitlab/manifests/gitlab-s3-cfg.yaml

# 2) бакеты в MinIO (создать в консоли заранее)
# object store + backups — список ниже

# 3) ArgoCD Application
kubectl apply -f 03-argocd/gitlab/application.yaml
kubectl -n argocd get application gitlab
kubectl get pods,ingress,certificate,pvc -n gitlab
```

Дождаться Running у webservice / sidekiq / gitaly / postgresql / redis и Ready у Certificate / Ingress (обычно 10–20 минут).

Root:

```bash
kubectl get secret gitlab-gitlab-initial-root-password -n gitlab \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

URL: <https://gitlab.lab-home.com> — логин `root`, пароль из Secret. После входа пароль лучше сменить.

## Что включено / выключено

Включено: webservice, sidekiq, gitaly, gitlab-shell, PostgreSQL, Redis, toolbox (+ backup CronJob), object store → MinIO.

Выключено: встроенный nginx-ingress, cert-manager chart, prometheus, grafana, registry, minio chart, kas, gitlab-exporter, gitlab-runner (отдельные apps).

## Object store (MinIO)

Secret `gitlab-s3-cfg`:

| Ключ | Назначение |
| --- | --- |
| `connection` | Rails object_store (Fog/AWS) |
| `s3cmd` | toolbox / backup-utility |

Endpoint в example: `https://minio-tenant-hl.minio-operator.svc.cluster.local:9000`, `path_style: true`, для s3cmd — `check_ssl_certificate = False`.

Бакеты (создать в MinIO):

| Bucket | Назначение |
| --- | --- |
| `gitlab-lab-home-lfs` | LFS |
| `gitlab-lab-home-artifacts` | CI artifacts |
| `gitlab-lab-home-uploads` | uploads |
| `gitlab-lab-home-packages` | packages |
| `gitlab-lab-home-mr-diffs` | external diffs |
| `gitlab-lab-home-terraform-state` | terraform state |
| `gitlab-lab-home-ci-secure-files` | CI secure files |
| `gitlab-lab-home-dependency-proxy` | dependency proxy |
| `gitlab-lab-home-backups` | toolbox backups |
| `gitlab-lab-home-backup-tmp` | tmp для backup |

`createBucketsJob.enabled: false` — бакеты не создаются chart’ом.

## TLS / Certificate

Ingress с аннотацией `cert-manager.io/cluster-issuer: lab-home-ca-issuer`. Chart сам заводит Certificate `gitlab-wildcard-tls`.

Если ключ/серт разъехались (ошибка mismatch), примените манифест с `rotationPolicy: Always`:

```bash
kubectl delete certificate gitlab-wildcard-tls -n gitlab
kubectl delete secret gitlab-wildcard-tls gitlab-wildcard-tls-ca gitlab-wildcard-tls-chain -n gitlab --ignore-not-found
kubectl apply -f 03-argocd/gitlab/manifests/certificate.yaml
kubectl get certificate gitlab-wildcard-tls -n gitlab
```

Без доверия к `lab-home-root-ca` на клиенте браузер будет ругаться на ЦС.

## Бэкап (toolbox)

Встроенный CronJob `gitlab-toolbox-backup`:

- schedule: `0 2 * * *`
- `extraArgs: --skip artifacts`
- PVC 2Gi (`topolvm-provisioner`)
- S3 через Secret `gitlab-s3-cfg` / ключ `s3cmd`
- buckets: `gitlab-lab-home-backups`, `gitlab-lab-home-backup-tmp`

Проверка:

```bash
kubectl get cronjob gitlab-toolbox-backup -n gitlab
kubectl create job -n gitlab gitlab-toolbox-backup-manual --from=cronjob/gitlab-toolbox-backup
kubectl logs -n gitlab job/gitlab-toolbox-backup-manual -f
```

**Prod-style** (отдельный `.s3cfg-backup`, если CronJob правят вручную вне Argo): пример Secret — `manifests/gitlab-s3-cfg-backup.example.yaml`. В lab обычно достаточно одного `gitlab-s3-cfg`.

Данные GitLab бэкапить через **toolbox / backup-utility**, не через Velero (Velero — только снимок namespace как DR).

## CI Runner

В chart runner выключен (`gitlab-runner.install: false`). Отдельные apps:

- [`../gitlab-runner/`](../gitlab-runner/README.md) — instances `project/`, `qwe/`

Tokens exporter: [`../gitlab-tokens-exporter/`](../gitlab-tokens-exporter/README.md).

## Проверка

```bash
kubectl get application gitlab -n argocd
kubectl get pods,ingress,certificate,pvc -n gitlab
kubectl get secret gitlab-s3-cfg -n gitlab
kubectl get cronjob -n gitlab
```

Ожидаемые поды (имена с суффиксами): `gitlab-gitaly-0`, `gitlab-postgresql-0`, `gitlab-redis-master-0`, webservice, sidekiq, gitlab-shell, toolbox.

## Частые проблемы

```bash
# webservice долго не Ready — смотреть probes / БД
kubectl describe pod -n gitlab -l app=webservice
kubectl logs -n gitlab -l app=webservice --tail=100

# нет S3 Secret → object store / backup падают
kubectl get secret gitlab-s3-cfg -n gitlab

# Certificate не Ready (issuer ещё не было)
kubectl describe certificate gitlab-wildcard-tls -n gitlab
kubectl get clusterissuer lab-home-ca-issuer

# PVC Pending
kubectl get pvc -n gitlab
kubectl get storageclass topolvm-provisioner
```

GitLab подняли раньше `lab-home-ca-issuer` — Certificate остаётся `False`, пока issuer Ready; затем обычно догоняет сам. Если нет — пересоздать Certificate (см. выше).

## Апгрейд chart

Как у Vault: оба chart в git, активный — path в `application.yaml`.

1. Сменить path на `03-argocd/gitlab/helm/charts/gitlab-…`.
2. Сверить breaking changes values с `helm/custom-values/lab-home.yaml`.
3. Закоммитить, дождаться sync (webservice/sidekiq могут рестартовать дольше обычного).
