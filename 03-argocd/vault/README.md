# Vault (ArgoCD Application)

Развёртывание HashiCorp Vault через ArgoCD

## Требования

- Ingress controller (nginx)
- StorageClass для PVC (по умолчанию)
- **cert-manager** и ClusterIssuer `selfsigned-issuer` (TLS для Ingress)
- **preconfigure** для Vault server и injector — см. раздел «Сертификаты» ниже.

## Сертификаты (как в vault_test)

- **Ingress:** cert-manager по аннотации создаёт Secret `vault-ingress-tls`. Отдельный Certificate не нужен.
- **Vault server и injector:** preconfigure — в `preconfigure/lab-home/` лежат манифесты `vault-ca` (ConfigMap), `vault-crt`, `vault-injector-crt` (Secret). Чарт монтирует их в под.

Перед деплоем: namespace и preconfigure (сертификаты Vault/injector):

```bash
kubectl create namespace vault --dry-run=client -o yaml | kubectl apply -f -
cd 03-argocd/vault/preconfigure/scripts
./generate-vault-certs.sh lab-home vault vault-lab-home
kubectl apply -f 03-argocd/vault/preconfigure/lab-home/
```

### Схема

| Компонент        | Источник              |
|------------------|-----------------------|
| Ingress (nginx)  | cert-manager → `vault-ingress-tls` |
| Vault server     | preconfigure → `vault-ca` (ConfigMap) + `vault-crt` (Secret) |
| Injector         | preconfigure → `vault-injector-crt` + caBundle |

## Установка и удаление через Helm

Развёртывание без ArgoCD: с хоста, где есть `kubectl` и репозиторий (или склонировать репо). Предварительно выполнить шаги из раздела «Сертификаты» (namespace + preconfigure).

**Установка или обновление (из корня репо):**

```bash
# Из каталога с репо (путь к чарту и values — относительно репо)
helm upgrade --install vault 03-argocd/vault/helm/charts/vault-1.14.0 \
  -n vault --create-namespace \
  -f 03-argocd/vault/helm/custom-values/lab-home.yaml
```

Или из каталога `03-argocd/vault`:

```bash
cd 03-argocd/vault
helm upgrade --install vault helm/charts/vault-1.14.0 \
  -n vault --create-namespace \
  -f helm/custom-values/lab-home.yaml
```

**Удаление:**

```bash
helm uninstall vault -n vault
# Namespace и preconfigure (ConfigMap/Secret) при этом не удаляются
kubectl delete pvc -n vault -l app.kubernetes.io/name=vault   # при необходимости очистить данные
```

При values `lab-home.yaml` (fullnameOverride: vault-lab-home) под называется **vault-lab-home-0** — в командах ниже (init, unseal, logs) подставлять его вместо `vault-0`.

---

## Порядок развёртывания (ArgoCD)

1. **Namespace и preconfigure** — выполнить команды из раздела «Сертификаты» выше.

2. **ArgoCD Application:**

   ```bash
   kubectl apply -f 03-argocd/vault/application.yaml
   ```

   Либо установить через **Helm** — см. раздел «Установка и удаление через Helm» выше.

3. **Проверка:**
   ```bash
   kubectl get pods -n vault
   kubectl get pvc -n vault
   kubectl get ingress -n vault
   ```
   Должен появиться PVC `data-vault-0`. Если PVC нет — см. раздел «PVC не создаётся» ниже.

4. **Доступ:** https://vault.lab-home.com (при необходимости добавить запись в hosts или DNS).

5. **Инициализация и unseal** — см. раздел ниже.

---

## Инициализация Vault (init и unseal)

После деплоя Vault находится в состоянии **sealed**. Нужно один раз выполнить инициализацию и затем распечатать (unseal) — вручную или через UI.

**Предварительно:** под `vault-0` в namespace `vault` в состоянии Running.

### 1. Инициализация (один раз)

Инициализация создаёт корневой ключ шифрования и выдаёт **unseal-ключи** и **root token**.

В values задан `VAULT_CACERT` в поде (см. `helm/custom-values/lab-home.yaml`), поэтому vault CLI при exec доверяет самоподписанному сертификату без ручного export.

```bash
# Инициализация (5 ключей, порог 3)
kubectl exec -it vault-0 -n vault -- vault operator init
```

Или с **одним** unseal-ключом (удобно для тестов):

```bash
kubectl exec -it vault-0 -n vault -- vault operator init -key-shares=1 -key-threshold=1
```

**Важно:** сохраните все unseal-ключи и root token в надёжное место. Без порогового числа ключей распечатать Vault будет нельзя.

### 2. Распечатывание (unseal)

После инициализации или рестарта пода введите unseal-ключи (по умолчанию 3 из 5). В поде уже задан `VAULT_CACERT`, дополнительный export не нужен.

```bash
kubectl exec -it vault-0 -n vault -- sh
vault operator unseal <Unseal Key 1>
vault operator unseal <Unseal Key 2>
vault operator unseal <Unseal Key 3>
vault status
exit
```

Если при init использовали 1 ключ — одной командой:

```bash
kubectl exec -it vault-0 -n vault -- vault operator unseal <ваш Unseal Key>
```

**Через UI:** откройте https://vault.lab-home.com, на странице Unseal введите ключи по очереди, затем войдите по Root Token.

### 3. Вход и первая настройка

В поде уже заданы `VAULT_ADDR` и `VAULT_CACERT`. Достаточно выставить токен:

```bash
kubectl exec -it vault-0 -n vault -- sh
export VAULT_TOKEN='<Initial Root Token>'
vault status
exit
```

В UI: войти с Root Token, при необходимости сменить root token, включить auth methods (Kubernetes, userpass), создать политики и секретные движки.

### 4. Автоматический unseal (опционально)

Для автоматического unseal после рестарта подов: Vault Agent с сохранённым ключом или внешний KMS (AWS KMS, Cloud KMS и т.д.). Ручной unseal после рестарта — нормальная практика для тестовых и небольших окружений.

### Шпаргалка

| Действие               | Команда |
|------------------------|--------|
| Init (1 ключ)          | `kubectl exec -it vault-0 -n vault -- vault operator init -key-shares=1 -key-threshold=1` |
| Unseal (1 ключ)         | `kubectl exec -it vault-0 -n vault -- vault operator unseal <KEY>` |
| Статус                 | `kubectl exec -it vault-0 -n vault -- vault status` |

---

## Структура каталога

- `application.yaml` — ArgoCD Application (path: `helm/charts/vault-1.14.0`, valueFiles: `../../custom-values/lab-home.yaml`)
- `ingress-nginx-rbac.yaml` — опционально: Role + RoleBinding для ingress-nginx (если 404 из‑за доступа к секретам в namespace vault)
- `certificate-ingress.yaml` — опционально: Certificate для cert-manager (если 404 из‑за порядка создания TLS-секрета)
- `preconfigure/` — сертификаты Vault и injector (openssl):
  - `scripts/generate-vault-certs.sh` — генерация CA и сертов; манифесты попадают в `preconfigure/<PROJECT>/`
  - `scripts/README.md` — описание скрипта
  - `keys/` — в .gitignore, сюда пишутся PEM-файлы после запуска скрипта
  - `<PROJECT>/` (например `lab-home/`) — готовые манифесты: `vault-ca.yaml`, `vault-crt.yaml`, `vault-injector-crt.yaml`
- `helm/charts/vault-1.14.0/` — чарт HashiCorp Vault (Vault 1.14.0), используется в `application.yaml`
- `helm/charts/vault-1.21.2/` — чарт новее (Vault 1.21.2), на выбор
- `helm/custom-values/lab-home.yaml` — values для окружения lab-home (release fullname: vault-lab-home)