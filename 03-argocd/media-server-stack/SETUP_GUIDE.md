# 🎬 Полное руководство по настройке медиа-конвейера

Это пошаговое руководство поможет настроить полноценный автоматизированный медиа-конвейер типа Netflix/Кинопоиск.

## 📋 Содержание

1. [Предварительные требования](#предварительные-требования)
2. [Шаг 1: Настройка qBittorrent](#шаг-1-настройка-qbittorrent)
3. [Шаг 2: Настройка Prowlarr](#шаг-2-настройка-prowlarr)
4. [Шаг 3: Настройка Radarr](#шаг-3-настройка-radarr)
5. [Шаг 4: Настройка Jellyfin](#шаг-4-настройка-jellyfin)
6. [Шаг 5: Настройка автоматизации](#шаг-5-настройка-автоматизации)
7. [Проверка работы конвейера](#проверка-работы-конвейера)

---

## Предварительные требования

✅ Убедитесь, что все приложения развернуты и доступны:
- **Jellyfin**: `https://jellyfin.lab-home.com`
- **Prowlarr**: `https://prowlarr.lab-home.com`
- **Radarr**: `https://radarr.lab-home.com`
- **qBittorrent**: `https://qbittorrent.lab-home.com`

✅ Все поды в состоянии `Running`:
```bash
kubectl get pods -n jellyfin
kubectl get pods -n prowlarr
kubectl get pods -n radarr
```

---

## Шаг 1: Настройка qBittorrent

### 1.1. Первый вход

1. Откройте `https://qbittorrent.lab-home.com`
2. Получите временный пароль:
   ```bash
   kubectl logs -n radarr deployment/qbittorrent | grep -i "temporary password"
   ```
3. Войдите с логином `admin` и временным паролем
4. **Сразу установите постоянный пароль**: Settings → Web UI → Authentication → установите новый пароль

### 1.2. Настройка путей загрузки

1. **Settings → Downloads**:
   - **Default Save Path**: `/downloads` ✅ (уже настроено)
   - **Keep incomplete files in**: `/downloads/incomplete` (опционально)
   - **Automatically add files from**: оставьте пустым

### 1.3. Настройка категорий (важно для автоматизации!)

1. **Settings → Categories → Add Category**:
   - **Name**: `radarr`
   - **Save Path**: `/downloads` (или оставьте пустым для использования Default Save Path)
2. Нажмите **Save**

> 💡 **Зачем нужна категория?** Radarr будет автоматически определять завершенные загрузки по категории `radarr`.

### 1.4. Настройка Web UI

1. **Settings → Web UI**:
   - **Port**: `8080` ✅ (уже настроено)
   - **IP address**: `0.0.0.0` ✅ (для доступа из кластера)
   - **Authentication**: ✅ включено (обязательно!)

### 1.5. Настройка BitTorrent

1. **Settings → BitTorrent**:
   - **Port used for incoming connections**: `6881` ✅ (уже настроено)
   - **Enable DHT**: включено (рекомендуется)
   - **Enable PeX**: включено (рекомендуется)
   - **Enable uTP**: включено (рекомендуется)

2. **Settings → Connection**:
   - **Global download rate limit**: 0 (без ограничений) или установите лимит
   - **Global upload rate limit**: установите разумный лимит (например, 1-2 МБ/с)

### 1.6. Сохранение настроек

Нажмите **Save** внизу страницы.

---

## Шаг 2: Настройка Prowlarr

### 2.1. Первый вход

1. Откройте `https://prowlarr.lab-home.com`
2. Пройдите мастер первоначальной настройки (язык, пароль и т.д.)

### 2.2. Добавление индексеров (источников медиа)

1. **Settings → Indexers → Add Indexer**
2. Выберите нужные торрент-трекеры из списка
3. Для каждого индексера:
   - Настройте учетные данные (если требуется)
   - Нажмите **Test** для проверки подключения
   - Нажмите **Save**

> 💡 **Рекомендации:**
> - Начните с 2-3 популярных трекеров
> - Используйте только проверенные источники
> - Регулярно проверяйте работоспособность индексеров

### 2.3. Интеграция с Radarr

1. **Получите API Key из Radarr**:
   - Откройте `https://radarr.lab-home.com`
   - Settings → General → Security → API Key
   - Скопируйте API Key (понадобится в следующем шаге)

2. **В Prowlarr**: Settings → Apps → Add Application → Radarr
3. Заполните:
   - **Name**: `Radarr`
   - **Prowlarr Server**: `http://prowlarr.prowlarr.svc.cluster.local:80`
   - **Radarr Server**: `http://radarr.radarr.svc.cluster.local:80`
   - **API Key**: вставьте API Key из Radarr
   - **Sync Level**: `Full Sync` ✅
   - **Tags**: оставьте пустым (или добавьте теги, если используете)
4. Нажмите **Test** - должно быть успешно ✅
5. Нажмите **Save**

> ⚠️ **Важно**: Radarr должен быть полностью запущен перед настройкой интеграции!

### 2.4. Проверка синхронизации индексеров

1. Подождите 10-30 секунд после сохранения
2. Откройте Radarr: `https://radarr.lab-home.com`
3. **Settings → Indexers** - должны появиться все индексеры из Prowlarr ✅

Если индексеры не появились:
- Проверьте URL и API Key в Prowlarr
- В Prowlarr: Settings → Apps → Radarr → Test Connection
- Проверьте логи: `kubectl logs -n prowlarr deployment/prowlarr --tail=50`

### 2.5. Настройка прокси (опционально, если требуется)

Если некоторые трекеры доступны только через прокси:

1. **Settings → General → Proxy**
2. Включите прокси:
   - **Proxy Type**: `HTTP` или `SOCKS5`
   - **Host**: адрес прокси-сервера
   - **Port**: порт прокси-сервера
   - **Username/Password**: если требуется
3. **Важно**: В поле **"Ignored Addresses"** добавьте:
   ```
   *.svc.cluster.local,*.svc,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
   ```
4. Нажмите **Save**

> 💡 Это позволит использовать прокси только для внешних трекеров, а внутренние соединения (Radarr, qBittorrent) будут идти напрямую.

---

## Шаг 3: Настройка Radarr

### 3.1. Первый вход

1. Откройте `https://radarr.lab-home.com`
2. Пройдите мастер первоначальной настройки (язык, пароль и т.д.)

### 3.2. Настройка Root Folder (медиа-библиотека)

1. **Settings → Media Management → Root Folders → Add Root Folder**
2. **Path**: `/media/movies`
3. Нажмите **Save**

> ⚠️ **Критически важно**: Этот путь должен точно совпадать с путем в Jellyfin!

### 3.3. Проверка индексеров (из Prowlarr)

1. **Settings → Indexers**
2. Должны быть видны все индексеры, синхронизированные из Prowlarr ✅
3. Если индексеров нет:
   - Проверьте настройки Prowlarr → Apps → Radarr
   - Проверьте API Key в Radarr
   - В Prowlarr: Settings → Apps → Radarr → Test Connection

### 3.4. Настройка Download Client (qBittorrent)

1. **Settings → Download Clients → Add → qBittorrent**
2. Заполните:
   - **Name**: `qBittorrent`
   - **Host**: `qbittorrent.radarr.svc.cluster.local`
   - **Port**: `80` (Service порт, не 8080!)
   - **Use SSL**: ❌ отключено (внутренний трафик)
   - **Username**: `admin` (или ваш логин qBittorrent)
   - **Password**: ваш пароль qBittorrent (постоянный, не временный!)
   - **Category**: `radarr` ✅ (категория, которую мы создали в qBittorrent)
   - **Priority**: `1` (высший приоритет)
   - **Initial State**: `Start` (автоматически начинать загрузку)
3. Нажмите **Test** - должно быть успешно ✅
4. Нажмите **Save**

### 3.5. Настройка Remote Path Mapping

Обычно **НЕ требуется**, если:
- qBittorrent и Radarr в одном namespace (`radarr`)
- Оба монтируют один PVC `radarr-downloads` в `/downloads`

Если нужно настроить:
1. **Settings → Download Clients → Remote Path Mappings → Add**
2. Заполните:
   - **Host**: `qbittorrent.radarr.svc.cluster.local`
   - **Remote Path**: `/downloads` (путь в qBittorrent)
   - **Local Path**: `/downloads` (путь в Radarr)
3. Нажмите **Save**

### 3.6. Настройка профилей качества

1. **Settings → Profiles**
2. Создайте или настройте профили:

   **HD-1080p** (рекомендуется для большинства фильмов):
   - **Name**: `HD-1080p`
   - **Allowed**: `Bluray-1080p`, `WEBDL-1080p`, `WEBRip-1080p`, `HDTV-1080p`
   - **Preferred**: `Bluray-1080p`, `WEBDL-1080p`
   - **Must Not Contain**: `CAM`, `TS`, `TC`, `SCR`

   **Ultra-HD** (для 4K контента):
   - **Name**: `Ultra-HD`
   - **Allowed**: `Bluray-2160p`, `WEBDL-2160p`, `WEBRip-2160p`
   - **Preferred**: `Bluray-2160p`, `WEBDL-2160p`
   - **Must Not Contain**: `CAM`, `TS`, `TC`, `SCR`

   **SD** (для экономии места):
   - **Name**: `SD`
   - **Allowed**: `Bluray-720p`, `WEBDL-720p`, `WEBRip-720p`, `HDTV-720p`, `SDTV`, `DVD`
   - **Preferred**: `Bluray-720p`, `WEBDL-720p`
   - **Must Not Contain**: `CAM`, `TS`, `TC`, `SCR`

3. Нажмите **Save** для каждого профиля

### 3.7. Настройка Media Management (автоматизация)

1. **Settings → Media Management**:
   - **Rename Movies**: ✅ включено (автоматическое переименование)
   - **Standard Movie Format**: `{Movie Title} ({Release Year})` (или настройте под себя)
   - **Delete Empty Folders**: ✅ включено
   - **Use Hardlinks instead of Copy**: ✅ включено (экономит место на диске)
   - **Import Extra Files**: включите, если нужны субтитры, обложки и т.д.

### 3.8. Настройка автоматического поиска

1. **Settings → Media Management → File Management**:
   - **Automatic Search**: ✅ включено (автоматический поиск при добавлении фильма)
   - **Upgrade Until Quality**: выберите максимальное качество (например, `Ultra-HD`)
   - **Minimum Availability**: `Announced` или `In Cinemas` (поиск начинается раньше)

2. **Settings → Profiles** → выберите профиль → **Upgrade Until Quality**: установите максимальное качество

### 3.9. Интеграция с Jellyfin

1. **Получите API Key из Jellyfin**:
   - Откройте `https://jellyfin.lab-home.com`
   - Dashboard → Settings → API Keys → Add API Key
   - Введите название (например, `Radarr`) и нажмите **Create**
   - Скопируйте API Key (понадобится в следующем шаге)

2. **В Radarr**: Settings → Connect → Add → Jellyfin/Emby
3. Заполните:
   - **Name**: `Jellyfin`
   - **Host**: `http://jellyfin.jellyfin.svc.cluster.local:80`
   - **Port**: `80`
   - **Use SSL**: ❌ отключено (внутренний трафик)
   - **API Key**: вставьте API Key из Jellyfin
   - **Notification Triggers**: 
     - ✅ `On Download` (уведомление при загрузке)
     - ✅ `On Upgrade` (уведомление при обновлении)
     - ✅ `On Rename` (уведомление при переименовании)
4. Нажмите **Test** - должно быть успешно ✅
5. Нажмите **Save**

> 💡 Теперь Jellyfin будет автоматически обновлять библиотеку при добавлении/обновлении фильмов!

### 3.10. Настройка мониторинга списков (опционально, но рекомендуется)

Radarr может автоматически добавлять фильмы из списков (IMDb, Trakt, TMDb и т.д.):

1. **Settings → Lists → Add List**
2. Выберите тип списка (например, `IMDb List`, `Trakt List`)
3. Настройте:
   - **Monitor**: `All Movies` (мониторить все фильмы из списка)
   - **Quality Profile**: выберите профиль (например, `HD-1080p`)
   - **Root Folder**: `/media/movies`
   - **Automatic Add**: ✅ включено
4. Нажмите **Save**

> 💡 Теперь фильмы из ваших списков будут автоматически добавляться и загружаться!

---

## Шаг 4: Настройка Jellyfin

### 4.1. Первый вход

1. Откройте `https://jellyfin.lab-home.com`
2. Пройдите мастер первоначальной настройки:
   - Выберите язык
   - Создайте администратора
   - Настройте библиотеки (пока пропустите, настроим позже)

### 4.2. Добавление медиа-библиотеки для фильмов

1. **Dashboard → Libraries → Add Media Library**
2. Заполните:
   - **Content Type**: `Movies` ✅
   - **Display Name**: `Фильмы` (или `Movies`)
   - **Folders → Add Folder**:
     - **Path**: `/media/movies` ✅ (должен совпадать с Radarr Root Folder!)
3. Нажмите **OK**

> ⚠️ **Критически важно**: Путь `/media/movies` должен точно совпадать с Root Folder в Radarr!

### 4.3. Настройка метаданных

1. **Dashboard → Libraries → Movies → Manage Library**
2. Настройте **Metadata downloaders**:
   - ✅ `TheMovieDb` (TMDb)
   - ✅ `OMDb`
   - ✅ `The Open Movie Database`
3. Настройте **Image fetchers**:
   - ✅ `TheMovieDb`
   - ✅ `FanArt`
   - ✅ `The Open Movie Database`
4. Нажмите **Save**

### 4.4. Настройка автоматического сканирования

1. **Dashboard → Scheduled Tasks**
2. Найдите задачу **"Scan media library"**
3. Настройте:
   - **Interval**: `Every 15 minutes` (или чаще, если нужно)
   - ✅ **Enabled**: включено
4. Нажмите **Save**

> 💡 Jellyfin будет автоматически сканировать библиотеку каждые 15 минут и находить новые фильмы!

### 4.5. Настройка пользователей (опционально)

1. **Dashboard → Users → Add User**
2. Создайте пользователей для членов семьи
3. Настройте права доступа для каждого пользователя

### 4.6. Настройка внешнего доступа (опционально)

Если хотите доступ к Jellyfin извне:

1. **Dashboard → Networking**
2. Настройте:
   - **Known Proxies**: добавьте IP-адреса ваших прокси (если используете)
   - **Enable automatic port mapping**: отключено (используем Ingress)

---

## Шаг 5: Настройка автоматизации

### 5.1. Автоматический поиск и загрузка (уже настроено!)

✅ **Уже работает** благодаря настройкам в Radarr:
- При добавлении фильма в Radarr → автоматический поиск через Prowlarr
- Найденный файл → автоматическая отправка в qBittorrent
- Завершенная загрузка → автоматический импорт в `/media/movies`
- Импортированный фильм → автоматическое уведомление Jellyfin
- Jellyfin → автоматическое сканирование библиотеки каждые 15 минут

### 5.2. Автоматическое обновление до лучшего качества

1. **В Radarr**: Settings → Media Management
2. Настройте:
   - **Upgrade Until Quality**: выберите максимальное качество (например, `Ultra-HD`)
   - **Minimum Age**: `0` (обновлять сразу) или установите задержку (например, `7 days`)

> 💡 Radarr будет автоматически искать и загружать лучшие версии фильмов!

### 5.3. Автоматическое удаление старых версий

1. **В Radarr**: Settings → Media Management
2. Настройте:
   - **Upgrade Until Quality**: установите максимальное качество
   - **Delete Old Files**: ✅ включено (удалять старые версии при обновлении)

### 5.4. Мониторинг списков (если настроили в шаге 3.10)

✅ **Уже работает**: Фильмы из ваших списков (IMDb, Trakt и т.д.) автоматически добавляются и загружаются!

### 5.5. Настройка уведомлений (опционально)

Radarr может отправлять уведомления в различные сервисы:

1. **Settings → Connect → Add** → выберите сервис (Telegram, Discord, Email и т.д.)
2. Настройте уведомления о:
   - Добавлении фильмов
   - Завершении загрузки
   - Обновлении качества
   - Ошибках

---

## Проверка работы конвейера

### Тест 1: Добавление фильма вручную

1. **В Radarr**: Movies → Add New
2. Найдите фильм (например, "The Matrix")
3. Выберите:
   - **Quality Profile**: `HD-1080p`
   - **Root Folder**: `/media/movies`
   - ✅ **Start search for missing movies**: включено
4. Нажмите **Add Movie**

**Что должно произойти автоматически:**
1. ✅ Radarr найдет фильм через Prowlarr
2. ✅ Radarr отправит файл в qBittorrent
3. ✅ В qBittorrent появится загрузка с категорией `radarr`
4. ✅ После завершения загрузки Radarr импортирует файл в `/media/movies`
5. ✅ Radarr уведомит Jellyfin
6. ✅ Jellyfin обновит библиотеку (в течение 15 минут или вручную)
7. ✅ Фильм появится в Jellyfin!

### Тест 2: Проверка логов

```bash
# Логи Radarr (должны быть сообщения о поиске, загрузке, импорте)
kubectl logs -n radarr deployment/radarr --tail=50

# Логи qBittorrent (должны быть сообщения о загрузках)
kubectl logs -n radarr deployment/qbittorrent --tail=50

# Логи Prowlarr (должны быть сообщения о запросах от Radarr)
kubectl logs -n prowlarr deployment/prowlarr --tail=50

# Логи Jellyfin (должны быть сообщения о сканировании библиотеки)
kubectl logs -n jellyfin deployment/jellyfin --tail=50
```

### Тест 3: Проверка файлов

```bash
# Проверьте загрузки в qBittorrent
kubectl exec -n radarr deployment/qbittorrent -- ls -la /downloads

# Проверьте импортированные фильмы в Radarr
kubectl exec -n radarr deployment/radarr -- ls -la /media/movies

# Проверьте доступность файлов в Jellyfin
kubectl exec -n jellyfin deployment/jellyfin -- ls -la /media/movies
```

### Тест 4: Проверка интеграций

1. **Prowlarr ↔ Radarr**:
   - В Prowlarr: Settings → Apps → Radarr → Test Connection ✅
   - В Radarr: Settings → Indexers - должны быть индексеры из Prowlarr ✅

2. **Radarr ↔ qBittorrent**:
   - В Radarr: Settings → Download Clients → qBittorrent → Test ✅
   - В qBittorrent: должны появляться загрузки с категорией `radarr` ✅

3. **Radarr ↔ Jellyfin**:
   - В Radarr: Settings → Connect → Jellyfin → Test ✅
   - В Jellyfin: Dashboard → Libraries → Movies - должны появляться новые фильмы ✅

---

## 🎉 Готово!

Ваш медиа-конвейер полностью настроен и автоматизирован! Теперь вы можете:

- ✅ Добавлять фильмы в Radarr → они автоматически загружаются и появляются в Jellyfin
- ✅ Использовать списки (IMDb, Trakt) → фильмы автоматически добавляются
- ✅ Просматривать фильмы в Jellyfin с красивыми обложками и метаданными
- ✅ Автоматически получать обновления до лучшего качества

---

## 🔧 Дополнительные настройки

### Оптимизация производительности

1. **Увеличьте ресурсы для Jellyfin** (если медленно работает):
   - Отредактируйте `03-argocd/media-server-stack/jellyfin/base/deployment.yaml`
   - Увеличьте `resources.limits.memory` и `resources.limits.cpu`

2. **Настройте кеширование в Jellyfin**:
   - Dashboard → Playback → Transcoding
   - Настройте кеш для транскодирования

### Резервное копирование

Регулярно делайте резервные копии конфигураций:
- Radarr: `/config` (PVC `radarr-config`)
- Prowlarr: `/config` (PVC `prowlarr-config`)
- qBittorrent: `/config` (PVC `qbittorrent-config`)
- Jellyfin: `/config` (PVC `jellyfin-config`)

### Мониторинг

Настройте мониторинг через Prometheus (если установлен):
- Все приложения поддерживают метрики Prometheus
- Настройте алерты на ошибки загрузки, недоступность сервисов и т.д.

---

## ❓ Частые проблемы

См. раздел **"Устранение неполадок"** в основном README.md файле.

---

**Последнее обновление**: 2026-01-26
