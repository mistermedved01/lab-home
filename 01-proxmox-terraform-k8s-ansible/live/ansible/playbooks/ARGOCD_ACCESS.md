# Доступ к ArgoCD Web UI

## Вариант 1: Port-Forward (быстрый способ)

### На control plane ноде (192.168.40.145):

```bash
# Подключение к control plane
ssh -i ~/.ssh/id_ed25519 ubuntu@192.168.40.145

# Запуск port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443 --kubeconfig=/home/ubuntu/.kube/config
```

### На локальной машине:

1. Откройте браузер: `https://localhost:8080`
2. Примите предупреждение о самоподписанном сертификате
3. **Логин:** `admin`
4. **Пароль:** `OcFjE0LhJncpUqJg`

---

## Вариант 2: Через Ingress (постоянный доступ) ✅ НАСТРОЕНО

### Текущее состояние:
- ✅ Ingress включен и настроен
- ✅ Ingress-nginx установлен с NodePort (HTTP: 30080, HTTPS: 30443)
- ✅ Ingress использует хост: `argocd.example.com`

### Доступ через Ingress:

**Вариант A: Через домен (рекомендуется)**

1. **Добавьте в `/etc/hosts` на вашей локальной машине:**
   ```
   192.168.40.145 argocd.example.com
   ```
   Или для worker ноды:
   ```
   192.168.40.146 argocd.example.com
   ```

2. **Откройте в браузере:**
   - **HTTP:** `http://argocd.example.com:30080` ✅ (используйте этот адрес!)
   - ⚠️ **Не используйте HTTPS** - ArgoCD настроен в insecure режиме для работы через HTTP

**Вариант B: Прямой доступ по IP (без домена)**

Откройте в браузере:
- HTTP: `http://192.168.40.145:30080` (control plane)
- HTTP: `http://192.168.40.146:30080` (worker)
- Добавьте заголовок `Host: argocd.example.com` в браузере (через расширение или curl)

**Вариант C: Через curl (для тестирования)**

```bash
curl -H "Host: argocd.example.com" http://192.168.40.145:30080
```

### Логин и пароль:
- **Логин:** `admin`
- **Пароль:** `OcFjE0LhJncpUqJg`

---

## Вариант 3: Прямой доступ через NodePort (если настроен)

Если ArgoCD сервис имеет тип NodePort, можно обращаться напрямую:

```bash
# Проверка типа сервиса
kubectl get svc argocd-server -n argocd --kubeconfig=/home/ubuntu/.kube/config

# Если NodePort, используйте указанный порт
```

---

## Получение пароля вручную (если нужно)

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" \
  --kubeconfig=/home/ubuntu/.kube/config | base64 -d
echo
```

---

## Рекомендация

Для быстрого тестирования используйте **Вариант 1 (Port-Forward)**.  
Для постоянного доступа настройте **Вариант 2 (Ingress)**.

