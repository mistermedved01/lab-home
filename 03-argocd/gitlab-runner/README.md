# GitLab Runner

Group runners для GitLab CI: отдельный Argo/Kustomize app и namespace на каждую группу. Manager и job-поды живут в своём namespace; изоляция между группами — через **tags** в GitLab UI и `.gitlab-ci.yml`.

Встроенный runner в Helm GitLab отключён (`gitlab-runner.install: false`).

Схема:

- Kustomize: Deployment + ConfigMap + RBAC в `base/`
- Секреты (token, S3 cache, CA) — `kubectl`, не Argo
- Kubernetes executor: job-поды в том же namespace, что и manager
- S3 cache → MinIO bucket `gitlab-lab-home-runner-cache`

| Instance | GitLab group | Argo app | Namespace | Runner name | Cache path | Tag (пример) |
| --- | --- | --- | --- | --- | --- | --- |
| `project/` | PROJECT | `gitlab-runner-project` | `gitlab-runner-project` | `project` | `gitlab-runner-cache/project` | `c` |
| `qwe/` | PROJECT/QWE | `gitlab-runner-qwe` | `gitlab-runner-qwe` | `qwe` | `gitlab-runner-cache/qwe` | `qwe` |

Общие параметры: GitLab `https://gitlab.lab-home.com`, concurrent `3`, job image `ubuntu:22.04`, manager `gitlab-runner:alpine-v17.10.1`, S3 `minio.lab-home.com`, hostAliases `192.168.7.240` → gitlab/harbor.lab-home.com.

## Предварительные требования

1. GitLab развёрнут и доступен
2. MinIO + bucket **`gitlab-lab-home-runner-cache`**
3. На клиенте/в CI — доверие к `lab-home-root-ca` (PEM в Secret `gitlab-runner-ca`)

## Структура

```text
gitlab-runner/
├── README.md
├── project/                    # group PROJECT
│   ├── application.yaml
│   ├── kustomization.yaml
│   ├── .gitignore
│   ├── base/
│   └── manifests/              # kubectl (не Argo)
└── qwe/                        # group PROJECT/QWE
    ├── application.yaml
    ├── kustomization.yaml
    ├── .gitignore
    ├── base/
    └── manifests/
```

Argo синкает только `base/` через kustomization. Секреты в `manifests/` **не** входят в Application.

## Развёртывание (на примере `project`)

Подставьте `project` или `qwe` и соответствующую GitLab-группу.

### 1) Runner в GitLab UI

Create **group** runner в нужной группе:

- Tags: уникальный tag (`c` для PROJECT, `qwe` для PROJECT/QWE)
- Run untagged: по политике группы
- Скопировать token `glrt-…`

### 2) Секреты

```bash
INSTANCE=project   # или qwe
NS=gitlab-runner-${INSTANCE}

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

cp "03-argocd/gitlab-runner/${INSTANCE}/manifests/gitlab-runner-token.example.yaml" \
   "03-argocd/gitlab-runner/${INSTANCE}/manifests/gitlab-runner-token.yaml"
cp "03-argocd/gitlab-runner/${INSTANCE}/manifests/gitlab-runner-cache-s3.example.yaml" \
   "03-argocd/gitlab-runner/${INSTANCE}/manifests/gitlab-runner-cache-s3.yaml"
cp "03-argocd/gitlab-runner/${INSTANCE}/manifests/gitlab-runner-ca.example.yaml" \
   "03-argocd/gitlab-runner/${INSTANCE}/manifests/gitlab-runner-ca.yaml"

# заполнить glrt token / S3 keys / PEM lab-home-root-ca, затем:
kubectl apply -f "03-argocd/gitlab-runner/${INSTANCE}/manifests/gitlab-runner-token.yaml"
kubectl apply -f "03-argocd/gitlab-runner/${INSTANCE}/manifests/gitlab-runner-cache-s3.yaml"
kubectl apply -f "03-argocd/gitlab-runner/${INSTANCE}/manifests/gitlab-runner-ca.yaml"
```

### 3) ArgoCD Application

```bash
kubectl apply -f 03-argocd/gitlab-runner/project/application.yaml
# и/или
kubectl apply -f 03-argocd/gitlab-runner/qwe/application.yaml

kubectl -n argocd get application gitlab-runner-project gitlab-runner-qwe
kubectl get pods -n gitlab-runner-project
kubectl get pods -n gitlab-runner-qwe
```

Дождаться Running у `gitlab-runner` в namespace; в GitLab UI runner **Online**, Owner = нужная группа.

## Secrets

| Secret | Keys | Назначение |
| --- | --- | --- |
| `gitlab-runner-token` | `runner-token` | Token group runner из GitLab UI |
| `gitlab-runner-cache-s3` | `accesskey`, `secretkey` | MinIO для `[runners.cache]` |
| `gitlab-runner-ca` | `lab-home-root-ca.crt` | Trust CA для TLS к GitLab/MinIO |

Файлы `manifests/*.yaml` с реальными значениями в `.gitignore` каждого instance — не коммитить.

## Tags и CI

Tags в ConfigMap **не** задаются — только при создании runner в GitLab. В `.gitlab-ci.yml`:

```yaml
job:
  tags:
    - qwe   # или c / project — как настроено в UI
```

Без matching tag job не попадёт на этот runner.

## Проверка

```bash
kubectl get pods -n gitlab-runner-project
kubectl get pods -n gitlab-runner-qwe
kubectl logs -n gitlab-runner-project deployment/gitlab-runner --tail=50
kubectl logs -n gitlab-runner-qwe deployment/gitlab-runner --tail=50
```

## Частые проблемы

```bash
# pod CrashLoop — нет token или битый config
kubectl logs -n gitlab-runner-project deployment/gitlab-runner
kubectl get secret gitlab-runner-token -n gitlab-runner-project

# cache / S3 errors
kubectl get secret gitlab-runner-cache-s3 -n gitlab-runner-project

# TLS к GitLab — проверить CA secret
kubectl get secret gitlab-runner-ca -n gitlab-runner-project
```

Runner Registered но jobs не берёт — проверьте tags в job и в GitLab UI runner settings.

## Новый group runner

Скопировать каталог `project/` или `qwe/`, заменить namespace/labels/cache path в `base/` и `kustomization.yaml`, создать Argo Application с новым именем.
