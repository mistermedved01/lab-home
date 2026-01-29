# Media Stack Bootstrap Job

Одноразовый Job, который извлекает ApiKey из `config.xml` Radarr и Prowlarr и записывает их в Secret `buildarr-secrets` (ключ `buildarr-secret.yml`) для использования Buildarr.

## Предварительные требования

- Radarr и Prowlarr развёрнуты и запущены (поды в состоянии Ready).
- Radarr должен сгенерировать ApiKey (откройте UI Radarr один раз или дождитесь первого запроса).

## Использование

1. Разверните bootstrap-приложение (или примените вручную):
   ```bash
   kubectl apply -k 03-argocd/media-server-stack/bootstrap/
   ```

2. Job монтирует PVC `radarr-config` (read-only) и использует `kubectl exec` для чтения конфига Prowlarr из пода Prowlarr. Убедитесь, что Radarr и Prowlarr в состоянии `Running`.

3. После завершения Job в Secret `buildarr-secrets` в namespace `radarr` появится ключ `buildarr-secret.yml` с `prowlarr.api_key` и `radarr.api_key`. При необходимости добавьте пароль qBittorrent и ApiKey Jellyfin в тот же Secret или в YAML-файл для Buildarr.

## Повторный запуск

Чтобы запустить Job снова (например, после сброса конфига *arr): удалите Job и примените заново или создайте новый Job из того же манифеста:

```bash
kubectl delete job media-stack-bootstrap -n radarr
kubectl apply -k 03-argocd/media-server-stack/bootstrap/
```

## Замечание по PVC

Job монтирует `radarr-config` (ReadWriteOnce). Если ваш драйвер хранилища не позволяет нескольким подам монтировать один и тот же RWO-том, Job может оставаться в Pending до тех пор, пока не будет запланирован на тот же узел, что и под Radarr.
