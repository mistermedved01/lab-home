# Buildarr — Config as Code для медиа-стека

Buildarr применяет декларативный конфиг `buildarr.yml` к Prowlarr и Radarr (download clients, root folders, Prowlarr Apps, Connect и т.д.). Все настройки версионируются в Git.

## Предварительные требования

- Secret `buildarr-secrets` в namespace `radarr` с ключом `buildarr-secret.yml`, содержащий как минимум:
  - `prowlarr.api_key`
  - `radarr.api_key`
- Создайте этот Secret вручную или один раз запустите [Bootstrap Job](../bootstrap/README.md) после развёртывания Radarr и Prowlarr.

Опционально добавьте в тот же Secret (или в `buildarr-secret.yml`) для полной конфигурации:
- пароль qBittorrent (для download client в Radarr/Sonarr)
- ApiKey Jellyfin (для Connect)

## Использование

1. Один раз запустите Bootstrap Job, чтобы заполнить `buildarr-secrets` ApiKey *arr (см. [bootstrap/README.md](../bootstrap/README.md)).

2. Запустите Buildarr Job для применения конфига:
   ```bash
   kubectl create job -n radarr buildarr-run-$(date +%s) --from=job/buildarr-run
   ```
   Или примените директорию (создаётся Job, он выполняется один раз):
   ```bash
   kubectl apply -k 03-argocd/media-server-stack/buildarr/
   ```

3. Редактируйте `base/configmap.yaml` (buildarr.yml) в Git, добавляя download clients, root folders, Prowlarr Apps, Connect (Jellyfin) и т.д. Затем перезапустите Job или синхронизируйте через ArgoCD.

## Структура конфигурации

- **buildarr.yml** (ConfigMap): hostname, порты и все настройки без секретов. Хранится в Git.
- **buildarr-secret.yml** (Secret): `api_key` для prowlarr и radarr; при необходимости добавьте пароль qbittorrent и api_key jellyfin. Не в Git; заполняется bootstrap или вручную.

Buildarr запускается в кластере и подключается к `prowlarr.prowlarr.svc.cluster.local:80` и `radarr.radarr.svc.cluster.local:80`.

## CronJob (опционально)

Чтобы применять конфиг по расписанию (например, ежедневно), замените Job на CronJob и запускайте в контейнере команду `buildarr run`.
