# Бэкапы GitLab

Подробное руководство по настройке, запуску и проверке встроенных бэкапов GitLab в данном окружении.

---

## Содержание

1. [Обзор](#обзор)
2. [Что попадает в бэкап](#что-попадает-в-бэкап)
3. [Конфигурация в репозитории](#конфигурация-в-репозитории)
4. [Подготовка хранилища (MinIO)](#подготовка-хранилища-minio)
5. [Secret с конфигом S3](#secret-с-конфигом-s3)
6. [Расписание и CronJob](#расписание-и-cronjob)
7. [Ручной запуск бэкапа](#ручной-запуск-бэкапа)
8. [Проверка результата](#проверка-результата)
9. [Восстановление](#восстановление)
10. [Устранение неполадок](#устранение-неполадок)
11. [Ссылки на файлы](#ссылки-на-файлы)

---

## Обзор

Бэкапы выполняет компонент **toolbox** чарта GitLab: по расписанию запускается CronJob, который:

- делает дамп PostgreSQL;
- создаёт архив репозиториев (Gitaly);
- при необходимости бэкапит объектное хранилище (артефакты, LFS и т.д.);
- упаковывает всё в один tar-архив и загружает его в S3-совместимое хранилище (в данном случае MinIO).

Имя CronJob в кластере: `gitlab-toolbox-backup`.  
Архивы хранятся в бакете `gitlab-toolbox-backup`, временные файлы — в `gitlab-toolbox-backup-tmp`.

---

## Что попадает в бэкап

| Компонент              | В бэкапе | Примечание |
|------------------------|----------|------------|
| PostgreSQL (БД)       | Да       | Полный дамп `gitlabhq_production`. |
| Репозитории (Gitaly)  | Да       | Все Git-репозитории. |
| Registry               | Нет      | Компонент отключён в lab-home. |
| Uploads / Artifacts / LFS / Packages и др. | Нет | В lab-home объектное хранилище отключено; соответствующих бакетов нет, скрипт их пропускает с сообщением «Skipping backup of …». |

Для восстановления инстанса достаточно архива с БД и репозиториями.

---

## Конфигурация в репозитории

### Values (`helm/custom-values/lab-home.yaml`)

**Глобальные бакеты:**

```yaml
global:
  appConfig:
    backups:
      bucket: gitlab-toolbox-backup      # бакет для готовых архивов
      tmpBucket: gitlab-toolbox-backup-tmp  # бакет для временных файлов
```

**Toolbox и бэкапы:**

```yaml
gitlab:
  toolbox:
    enabled: true
    backups:
      cron:
        enabled: true
        schedule: "0 2 * * *"   # каждый день в 02:00 (UTC)
        persistence:
          enabled: true
          size: 10Gi
          storageClass: local-path
      objectStorage:
        backend: s3
        config:
          secret: gitlab-backup-s3-config   # имя Secret в namespace gitlab
          key: config                        # ключ с содержимым .s3cfg
```

- Расписание можно менять (cron-формат).
- `persistence` — PVC для временных файлов во время создания архива.
- Доступ к MinIO задаётся только через Secret; в values указывается лишь имя секрета и ключ.

---

## Подготовка хранилища (MinIO)

1. Создайте в MinIO два бакета (например, через консоль или mc):
   - `gitlab-toolbox-backup` — для итоговых архивов;
   - `gitlab-toolbox-backup-tmp` — для временных файлов.

2. Создайте пользователя/ключи доступа с правами на эти бакеты (чтение/запись).  
   Для lab-home используется отдельный access key / secret key (не root MinIO).

Имена бакетов должны совпадать с `global.appConfig.backups.bucket` и `tmpBucket` в values.

---

## Secret с конфигом S3

Скрипт бэкапа использует конфиг в формате **.s3cfg** (s3cmd). Он должен лежать в Secret `gitlab-backup-s3-config` в namespace `gitlab`, в ключе `config`.

### Вариант 1: внутренний сервис MinIO (рекомендуется)

Из кластера лучше обращаться к MinIO по внутреннему сервису, без Ingress и без проблем с SSL/маршрутизацией:

- **Сервис MinIO tenant** (порт 9000, в lab-home — HTTPS):  
  `minio-tenant-hl.minio-operator.svc.cluster.local:9000`

Пример содержимого для `stringData.config`:

```ini
[default]
access_key = <ACCESS_KEY>
secret_key = <SECRET_KEY>
bucket_location = us-east-1
host_base = minio-tenant-hl.minio-operator.svc.cluster.local:9000
host_bucket = minio-tenant-hl.minio-operator.svc.cluster.local:9000/%(bucket)
use_https = True
check_ssl_certificate = False
```

`check_ssl_certificate = False` нужен, потому что сертификат на внутреннем имени обычно не совпадает с hostname.

### Вариант 2: доступ через Ingress (minio.lab-home.com)

Если использовать внешний хост (Ingress):

- Убедитесь, что из пода в кластере имя `minio.lab-home.com` действительно резолвится и идёт в MinIO (а не на другой сервис).
- Для самоподписанного или «чужого» сертификата добавьте:  
  `check_ssl_certificate = False`

Пример:

```ini
[default]
access_key = <ACCESS_KEY>
secret_key = <SECRET_KEY>
bucket_location = us-east-1
host_base = minio.lab-home.com
host_bucket = minio.lab-home.com/%(bucket)
use_https = True
check_ssl_certificate = False
```

### Создание Secret

**Из файла (реальные ключи не коммитить):**

```bash
# Отредактируйте 03-argocd/gitlab/gitlab/gitlab-backup-s3-secret.yaml (файл в .gitignore),
# затем:
kubectl apply -f 03-argocd/gitlab/gitlab/gitlab-backup-s3-secret.yaml
```

**Из literal:**

```bash
kubectl create secret generic gitlab-backup-s3-config -n gitlab \
  --from-literal=config="[default]
access_key = YOUR_ACCESS_KEY
secret_key = YOUR_SECRET_KEY
bucket_location = us-east-1
host_base = minio-tenant-hl.minio-operator.svc.cluster.local:9000
host_bucket = minio-tenant-hl.minio-operator.svc.cluster.local:9000/%(bucket)
use_https = True
check_ssl_certificate = False"
```

**Из отдельного файла .s3cfg:**

```bash
kubectl create secret generic gitlab-backup-s3-config -n gitlab \
  --from-file=config=/path/to/.s3cfg
```

Файл-пример без секретов для прода: `gitlab/gitlab-backup-s3-secret.example.yaml`.  
Для теста (restore): `gitlab-test/gitlab-backup-s3-secret.example.yaml` (имя секрета `gitlab-test-backup-s3-config`).  
Файл с реальными ключами для прода: `gitlab/gitlab-backup-s3-secret.yaml` (должен быть в `.gitignore`).

---

## Расписание и CronJob

- **Имя CronJob:** `gitlab-toolbox-backup`
- **Namespace:** `gitlab`
- **Расписание по умолчанию:** `0 2 * * *` (ежедневно в 02:00 UTC)

Проверка:

```bash
kubectl get cronjob -n gitlab
kubectl get jobs -n gitlab
```

После синхронизации ArgoCD CronJob создаётся автоматически; при изменении `schedule` в values расписание обновится при следующем sync.

---

## Ручной запуск бэкапа

Запуск одного бэкапа без ожидания расписания:

```bash
kubectl create job -n gitlab gitlab-toolbox-backup-manual \
  --from=cronjob/gitlab-toolbox-backup
```

Просмотр логов:

```bash
kubectl logs -n gitlab -l job-name=gitlab-toolbox-backup-manual -c toolbox-backup -f
```

Проверка статуса Job:

```bash
kubectl get job -n gitlab gitlab-toolbox-backup-manual
```

Успешное завершение: `COMPLETIONS 1/1`, в логах строка вида:

```text
[DONE] Backup can be found at s3://gitlab-toolbox-backup/<timestamp>_<version>_gitlab_backup.tar
```

---

## Проверка результата

1. **В кластере:**  
   Job должен быть `Complete`, в логах пода — строка `[DONE] Backup can be found at s3://...`.

2. **В MinIO:**  
   В бакете `gitlab-toolbox-backup` должен появиться объект с именем вида  
   `1772356789_2026_03_01_18.7.1-ee_gitlab_backup.tar` (timestamp и версия могут отличаться).

3. **Сообщения «Skipping backup of …»** для registry, uploads, artifacts, lfs, packages и т.д. в lab-home **нормальны**: эти компоненты отключены, бакетов нет — скрипт их пропускает. В архиве есть БД и репозитории.

---

## Восстановление

Кратко (подробности — в [официальной документации GitLab](https://docs.gitlab.com/ee/raketasks/backup_restore.html)):

1. Остановить приложение (webservice, sidekiq и т.д.) или перевести в режим обслуживания.
2. Скачать нужный архив из S3/MinIO в под toolbox или в место, откуда выполняется restore.
3. Восстановить БД и репозитории через `gitlab-backup restore` (внутри образа toolbox), предварительно настроив тот же конфиг S3 или положив архив в ожидаемый путь.
4. Запустить приложение и проверить данные.

Для восстановления в тот же инстанс важно использовать ту же версию GitLab, что и при создании бэкапа.

---

## Устранение неполадок

### SSL: «certificate verify failed: Hostname mismatch»

- **Причина:** клиент проверяет сертификат, а он выдан для другого имени (например, для Ingress).
- **Решение:** в .s3cfg добавить `check_ssl_certificate = False` или перейти на внутренний сервис MinIO (см. [Secret с конфигом S3](#secret-с-конфигом-s3)).

### «Client sent an HTTP request to an HTTPS server»

- **Причина:** MinIO на порту 9000 отвечает по HTTPS, а в конфиге указано `use_https = False`.
- **Решение:** задать `use_https = True` и при необходимости `check_ssl_certificate = False`.

### S3 error 404 или HTML «Strona nie została znaleziona» / «Error 400»

- **Причина:** запрос к указанному host (например, `minio.lab-home.com`) уходит не в MinIO, а на другой сервис (веб-сайт, другой Ingress).
- **Решение:** использовать внутренний сервис MinIO:  
  `host_base = minio-tenant-hl.minio-operator.svc.cluster.local:9000` (и при необходимости HTTPS + `check_ssl_certificate = False`).

### «Bucket 'gitlab-uploads' does not exist» и аналоги для других бакетов

- **Причина:** скрипт проверяет наличие бакетов для отключённых компонентов (uploads, artifacts, registry и т.д.).
- **Решение:** ничего делать не нужно — скрипт пропускает эти части. Важно, чтобы существовали только бакеты `gitlab-toolbox-backup` и `gitlab-toolbox-backup-tmp`.

### Pod постоянно перезапускается (RestartCount растёт)

- Смотреть логи предыдущего контейнера:  
  `kubectl logs -n gitlab <pod-name> -c toolbox-backup --previous`
- Частые причины: неверный или отсутствующий Secret, неверный host/port, сеть до MinIO.

### Проверить наличие Secret и его ключа

```bash
kubectl get secret gitlab-backup-s3-config -n gitlab -o jsonpath='{.data.config}' | base64 -d
```

Должно вывести содержимое .s3cfg (без реальных секретов в лог при необходимости).

---

## Ссылки на файлы

| Файл | Назначение |
|------|------------|
| `helm/custom-values/lab-home.yaml` | Конфигурация бэкапов (бакеты, cron, secret). |
| `gitlab/gitlab-backup-s3-secret.example.yaml` | Пример Secret для прода (можно коммитить). |
| `gitlab-test/gitlab-backup-s3-secret.example.yaml` | Пример Secret для теста/restore (можно коммитить). |
| `gitlab/gitlab-backup-s3-secret.yaml` | Реальный Secret с ключами для прода (в `.gitignore`, не коммитить). |
| `README.md` | Общее описание GitLab и краткий блок про бэкапы. |

После изменения Secret или values не забывайте:

- `kubectl apply -f ...` для Secret;
- дождаться sync ArgoCD для изменений в values (CronJob подхватит новый расписание и конфиг при следующем запуске).
