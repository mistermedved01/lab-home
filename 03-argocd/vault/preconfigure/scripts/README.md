# Скрипты предконфигурации Vault

## generate-vault-certs.sh

Генерация CA и TLS-сертификатов для Vault server и Vault Agent Injector.

### Запуск

**Интерактивно** (скрипт запросит параметры):

```bash
./generate-vault-certs.sh
```

Будут запрошены:

- **Имя проекта** (например `lab-home`) — обязательно;
- **Namespace k8s для Vault** — по умолчанию `vault`;
- **Имя Helm-релиза (fullnameOverride)** — по умолчанию `vault`.

**Без запросов** (всё передаётся аргументами):

```bash
./generate-vault-certs.sh <PROJECT> [NAMESPACE] [RELEASE]
```

Примеры:

```bash
./generate-vault-certs.sh lab-home
./generate-vault-certs.sh lab-home vault vault
./generate-vault-certs.sh my-project my-ns my-release
```

### Куда пишутся файлы

- **Сертификаты (PEM) и caBundle:** `preconfigure/keys/<PROJECT>/` — vault-ca.crt, vault-ca.key, vault-crt.crt, vault-crt.key, vault-injector-crt.crt, vault-injector-crt.key, **caBundle.b64** (CA в base64 для custom-values). Каталог `keys/` в `.gitignore` — ключи не коммитятся.
- **vault-ca.srl** — служебный файл OpenSSL (номер серии для подписанных сертификатов). Создаётся при первой подписи и обновляется при следующих; для деплоя в K8s не нужен, можно не трогать.
- **Манифесты:** скрипт создаёт каталог **`preconfigure/<PROJECT>/`** и в нём готовые файлы:
  - `vault-ca.yaml` — ConfigMap с CA;
  - `vault-crt.yaml` — Secret для Vault server;
  - `vault-injector-crt.yaml` — Secret для injector.

Во всех манифестах подставлен выбранный namespace.

### Что такое каждый артефакт (сертификаты и caBundle)

Скрипт генерирует один **CA** (корневой сертификат) и два **серверных сертификата** (Vault server и Vault Agent Injector), подписанных этим CA. Ниже — куда что попадает и зачем.

| Артефакт | Файлы в `keys/<PROJECT>/` | Где лежит | Содержимое | Назначение |
|----------|--------------------------|-----------|------------|------------|
| **vault-ca.yaml** | `vault-ca.crt` | ConfigMap в `preconfigure/<PROJECT>/vault-ca.yaml` | CA в PEM (текст `-----BEGIN CERTIFICATE-----` … `-----END CERTIFICATE-----`) | Общий корень доверия. Монтируется в поды Vault и приложений, чтобы они доверяли TLS Vault и injector. |
| **vault-crt.yaml** | `vault-crt.crt`, `vault-crt.key` | Secret в `preconfigure/<PROJECT>/vault-crt.yaml` | **tls.crt** — сертификат Vault server (base64);<br>**tls.key** — приватный ключ Vault server (base64). | TLS для самого Vault: сервер отдаёт этот сертификат на порту 8200. Монтируется в поды Vault server. |
| **vault-injector-crt.yaml** | `vault-injector-crt.crt`, `vault-injector-crt.key` | Secret в `preconfigure/<PROJECT>/vault-injector-crt.yaml` | **tls.crt** — сертификат injector’а (base64);<br>**tls.key** — приватный ключ injector’а (base64). | TLS webhook’а injector’а. API‑сервер K8s вызывает этот webhook по HTTPS; injector отдаёт этот сертификат. |
| **caBundle** (поле в values) | `vault-ca.crt` → сохраняется как **caBundle.b64** в `keys/` | custom-values: `injector.certs.caBundle` | Тот же CA, что в vault-ca.yaml, но в **base64** (одна строка) | При `helm install` подставляется в MutatingWebhookConfiguration. Нужен, чтобы API‑сервер K8s доверял сертификату injector’а (проверка TLS при вызове webhook). |

**Важно:** в custom-values вставляется **не** vault-crt.yaml и **не** vault-injector-crt.yaml, а именно **caBundle** — base64 CA. Скрипт сохраняет его в `keys/<PROJECT>/caBundle.b64`; содержимое этого файла нужно вставить в `injector.certs.caBundle`.

**Цепочка:** один CA подписывает оба серверных сертификата (vault-crt.yaml и vault-injector-crt.yaml). ConfigMap vault-ca.yaml и поле caBundle содержат один и тот же CA: первый — для подов (PEM), второе — для MutatingWebhookConfiguration (base64).

### Что сделать после запуска

1. В **custom-values** чарта (`charts/vault-1.14.0/custom-values/<PROJECT>-vault.yaml`) вставить в **injector.certs.caBundle** содержимое файла `keys/<PROJECT>/caBundle.b64` (одна строка base64).

2. Применить предконфигурацию:

   ```bash
   kubectl apply -f preconfigure/<PROJECT>/
   ```

Дальше — установка Vault по инструкциям.