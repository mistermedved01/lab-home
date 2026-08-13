# Postgres Operator (Zalando)

## Определения

| Термин | Что это |
|--------|---------|
| **Postgres Operator** | Kubernetes-контроллер: читает CR `postgresql` и создаёт/чинит Postgres-кластер (поды, Service, PVC, секреты с паролями). Сам данные приложений не хранит. |
| **Zalando** | Компания-автор оператора ([zalando/postgres-operator](https://github.com/zalando/postgres-operator)). API group `acid.zalan.do`. |
| **Spilo** | Docker-образ Postgres + Patroni + утилиты (в т.ч. WAL-G). Именно его крутят поды кластера (`ghcr.io/zalando/spilo-16:…`). |
| **WAL-G** | Инструмент бэкапа/restore Postgres (WAL + basebackup) в S3-совместимое хранилище. В lab — в MinIO bucket `postgresql-lab-home-backup`. |
| **CRD** | Custom Resource Definition — схема/тип объекта в API Kubernetes (не Pod/Service из коробки). Появляется после установки оператора, напр. `postgresqls.acid.zalan.do`. |
| **CR** | Custom Resource — конкретный экземпляр по этой схеме. У нас это манифест `kind: postgresql` (`apiVersion: acid.zalan.do/v1`), напр. `psql-keycloak`. Оператор читает CR и по нему поднимает кластер БД. |

Контроллер смотрит CR `postgresql.acid.zalan.do` и поднимает кластеры на базе Spilo.

## Зачем он здесь

- Приложению нужна Postgres → **не** включаем встроенный Postgres из Helm-чарта.
- Вместо этого: манифест `kind: postgresql` (обычно в ns приложения) → оператор создаёт STS/Service/PVC/Secret с паролями.
- Приложение только подключается к готовому Service + `existingSecret`.

**Один оператор на кластер**, **отдельный Postgres-кластер (CR) на каждое приложение** — изоляция, свои бэкапы, проще удалять вместе с app.

Пример: Keycloak → CR `psql-keycloak` в ns `keycloak`.  

## Что ставится

| Компонент | Описание |
|-----------|----------|
| Helm chart | `postgres-operator` 1.13.0 |
| Spilo image | `ghcr.io/zalando/spilo-16:3.3-p3` |
| ConfigMap | `postgres-pod-config` — env для WAL-G → MinIO (на все PG-поды) |
| Namespace | `postgres-operator` |
| CRD | `postgresqls.acid.zalan.do` (+ operatorconfigurations, postgresteams) |

`watched_namespace: "*"` — оператор видит CR во всех namespace’ах.

WAL-G пишет в bucket **`postgresql-lab-home-backup`**  
(S3: `https://minio-tenant-hl.minio-operator.svc.cluster.local:9000`).

Ключи S3 — не в ConfigMap, а в Secret `postgres-pod-secrets` **в namespace того Postgres-кластера** (см. Keycloak).

## Предварительные требования

- MinIO Tenant (`03-argocd/minio`) — если нужны бэкапы WAL-G
- StorageClass `topolvm-provisioner` (PVC `pgdata` у кластеров)

## Развёртывание

```bash
kubectl apply -f 03-argocd/postgres-operator/application.yaml
# дождаться Ready
kubectl get pods -n postgres-operator
kubectl get crd postgresqls.acid.zalan.do
```

Проверка кластеров БД:

```bash
kubectl get postgresql -A
```

## Кто использует

Приложения поднимают свой Postgres через CR `postgresql` в своём namespace (и при WAL-G — Secret `postgres-pod-secrets` там же).

| Приложение | CR / ns | Документация |
|------------|---------|--------------|
| Keycloak | `psql-keycloak` / `keycloak` | [`../keycloak/README.md`](../keycloak/README.md) |
