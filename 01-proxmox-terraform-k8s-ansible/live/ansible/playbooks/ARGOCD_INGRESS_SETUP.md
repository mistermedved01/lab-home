# Доступ к ArgoCD через Ingress ✅

## Статус
✅ Ingress настроен и работает  
✅ Ingress-nginx доступен через NodePort  
✅ ArgoCD доступен через Ingress

## Быстрый доступ

### Шаг 1: Добавьте домен в hosts файл

**На Windows** (откройте PowerShell от имени администратора):
```powershell
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "192.168.40.145 argocd.example.com"
```

**На Linux/Mac:**
```bash
echo "192.168.40.145 argocd.example.com" | sudo tee -a /etc/hosts
```

### Шаг 2: Откройте в браузере

**ВАЖНО: Используйте HTTP (не HTTPS)!**

```
http://argocd.example.com:30080
```

⚠️ **Не используйте HTTPS** - ArgoCD настроен в insecure режиме для работы через HTTP.

### Шаг 3: Войдите в ArgoCD

- **Логин:** `admin`
- **Пароль:** `OcFjE0LhJncpUqJg`

---

## Альтернативные способы доступа

### Вариант 1: Прямой доступ по IP (без hosts файла)

Используйте расширение браузера для изменения заголовка Host, или curl:

```bash
curl -H "Host: argocd.example.com" http://192.168.40.145:30080
```

### Вариант 2: Через worker ноду

Если ingress-nginx работает на worker ноде:
```
http://192.168.40.146:30080
```
(Также нужен заголовок Host: argocd.example.com)

---

## Проверка статуса

**На control plane ноде (192.168.40.145):**

```bash
# Проверка ingress
kubectl get ingress -n argocd --kubeconfig=/home/ubuntu/.kube/config

# Проверка ingress-nginx
kubectl get svc -n ingress-nginx --kubeconfig=/home/ubuntu/.kube/config

# Проверка pods ArgoCD
kubectl get pods -n argocd --kubeconfig=/home/ubuntu/.kube/config
```

---

## Изменение домена (если нужно)

Если хотите использовать другой домен (например, `argocd.local`):

1. Обновите `helm/argocd/values.yaml`:
```yaml
server:
  ingress:
    hosts:
      - argocd.local  # ваш домен
```

2. Обновите ArgoCD:
```bash
helm upgrade argocd argo/argo-cd \
  --namespace argocd \
  --values /tmp/argocd-values.yaml \
  --kubeconfig=/home/ubuntu/.kube/config
```

3. Обновите hosts файл с новым доменом

---

## Устранение проблем

**Проблема:** Не открывается страница  
**Решение:** 
- Проверьте, что ingress-nginx работает: `kubectl get pods -n ingress-nginx`
- Проверьте, что ArgoCD pods готовы: `kubectl get pods -n argocd`
- Проверьте hosts файл

**Проблема:** Ошибка SSL  
**Решение:** Используйте HTTP (порт 30080) вместо HTTPS, или примите самоподписанный сертификат

**Проблема:** 404 Not Found  
**Решение:** Убедитесь, что заголовок Host установлен правильно (через hosts файл или расширение браузера)

