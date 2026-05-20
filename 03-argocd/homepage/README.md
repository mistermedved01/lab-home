# Homepage (ArgoCD Application)

Развёртывание [gethomepage/homepage](https://github.com/gethomepage/homepage) через ArgoCD.

## Требования

- Ingress controller (nginx)
- **cert-manager** и ClusterIssuer `lab-home-ca-issuer`

## Структура

| Компонент | Путь |
|-----------|------|
| ArgoCD Application | `03-argocd/homepage/application.yaml` |
| Custom values (lab-home) | `03-argocd/homepage/helm/custom-values/lab-home.yaml` |
| Helm chart | `03-argocd/homepage/helm/charts/homepage-2.1.0` |

## Подготовка чарта (один раз)

Чарт: [jameswynn/helm-charts — homepage](https://github.com/jameswynn/helm-charts/tree/main/charts/homepage). Если каталог `helm/charts/homepage-2.1.0` отсутствует:

```bash
cd 03-argocd/homepage/helm/charts
helm repo add jameswynn https://jameswynn.github.io/helm-charts
helm pull jameswynn/homepage --version 2.1.0 --untar
mv homepage homepage-2.1.0
```

## Развёртывание через ArgoCD

1. Применить Application:
   ```bash
   kubectl apply -f 03-argocd/homepage/application.yaml
   ```

2. Дождаться готовности:
   ```bash
   kubectl get pods -n homepage -w
   ```

3. Доступ: `https://homepage.lab-home.com`

## Настройка

- Ingress, TLS, `HOMEPAGE_ALLOWED_HOSTS`, ресурсы — `helm/custom-values/lab-home.yaml`
- Дашборд (сервисы, виджеты, закладки) — секция `config` в том же файле; см. [документацию Homepage](https://gethomepage.dev/)

## Установка без ArgoCD (Helm)

```bash
helm upgrade --install homepage 03-argocd/homepage/helm/charts/homepage-2.1.0 \
  -n homepage --create-namespace \
  -f 03-argocd/homepage/helm/custom-values/lab-home.yaml
```
