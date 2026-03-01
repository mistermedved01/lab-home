# GitLab TEST (проверка восстановления)

Второй инстанс GitLab для теста восстановления из бэкапа.

- **Namespace:** `gitlab-test`
- **URL:** https://gitlab-test.lab-home.com
- **ArgoCD Application:** `gitlab-test/application.yaml`
- **Values:** `helm/custom-values/lab-home-test.yaml`

## Развёртывание

1. Добавь DNS: `gitlab-test.lab-home.com` → IP Ingress/узла.
2. Применить Application:
   ```bash
   kubectl apply -f 03-argocd/gitlab/gitlab-test/application.yaml
   ```
3. Дождаться синка и готовности подов в `gitlab-test`.

## Восстановление из бэкапа (тестовый restore)

В values теста бакет уже указан на продовый (`gitlab-toolbox-backup`), поэтому restore читает бэкапы напрямую из S3.

### 1. Secret S3 в gitlab-test

Нужен доступ к тому же MinIO (те же учётные данные, что и у продового бэкапа). Пример манифеста: `gitlab-test/gitlab-backup-s3-secret.example.yaml`. Имя секрета в тесте: `gitlab-test-backup-s3-config`.

```bash
kubectl create secret generic gitlab-test-backup-s3-config -n gitlab-test \
  --from-file=config=/path/to/.s3cfg
```

Файл `.s3cfg` — тот же, что для продового GitLab (доступ к бакету `gitlab-toolbox-backup`). После создания секрета перезапусти toolbox, чтобы под подхватил конфиг:

```bash
kubectl delete pods -lapp=toolbox,release=gitlab-test -n gitlab-test
```

### 2. Узнать ID бэкапа

Имя файла в S3 имеет вид `<timestamp>_gitlab_backup.tar`. ID для restore — это `<timestamp>` (например `1698765432_2024_01_15_17.0.0_gitlab_backup`). Посмотреть можно в MinIO в бакете `gitlab-toolbox-backup` или через CLI.

### 3. Остановить клиенты БД

```bash
kubectl scale deploy -lapp=sidekiq,release=gitlab-test -n gitlab-test --replicas=0
kubectl scale deploy -lapp=webservice,release=gitlab-test -n gitlab-test --replicas=0
kubectl scale deploy -lapp=prometheus,release=gitlab-test -n gitlab-test --replicas=0
```

(Если prometheus не ставился в тесте — команда для него просто не найдёт deploy, это нормально.)

### 4. Запустить restore

```bash
TOOLBOX=$(kubectl get pods -n gitlab-test -lapp=toolbox,release=gitlab-test -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it -n gitlab-test "$TOOLBOX" -- backup-utility --restore -t <BACKUP_ID>
```

Вместо `<BACKUP_ID>` подставь timestamp из имени файла (без `_gitlab_backup.tar`). Процесс может занять много времени в зависимости от размера бэкапа.

### 5. Поднять приложение обратно

```bash
kubectl scale deploy -lapp=sidekiq,release=gitlab-test -n gitlab-test --replicas=1
kubectl scale deploy -lapp=webservice,release=gitlab-test -n gitlab-test --replicas=1
kubectl scale deploy -lapp=prometheus,release=gitlab-test -n gitlab-test --replicas=1
```

### 6. (Опционально) Kubernetes-настройки после restore

Если бэкап с другого инстанса (в т.ч. с этого же чарта), можно выполнить:

```bash
kubectl exec -it -n gitlab-test "$TOOLBOX" -- gitlab-rails runner -e production /scripts/custom-instance-setup
```

После этого перезапустить webservice и sidekiq:

```bash
kubectl delete pods -lapp=sidekiq,release=gitlab-test -n gitlab-test
kubectl delete pods -lapp=webservice,release=gitlab-test -n gitlab-test
```

### 7. Проверка

Открой https://gitlab-test.lab-home.com и проверь данные (проекты, пользователи). Пароль root — из бэкапа (секрет `gitlab-initial-root-password` в тесте не обновляется). Сброс пароля root при необходимости — см. [BACKUPS.md](BACKUPS.md) или [документацию GitLab](https://docs.gitlab.com/charts/backup-restore/restore/).

---

Cron-бэкапы для тестового инстанса отключены (`backups.cron.enabled: false`).
