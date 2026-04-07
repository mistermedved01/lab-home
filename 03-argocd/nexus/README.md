# Nexus Repository Manager (ArgoCD Application)

Развёртывание Sonatype Nexus Repository Manager через ArgoCD.

## Требования

- Ingress controller (nginx)
- StorageClass для PVC
- **cert-manager** и ClusterIssuer `selfsigned-issuer` (TLS для Ingress)

## Структура

| Компонент        | Путь |
|------------------|------|
| ArgoCD Application | `03-argocd/nexus/application.yaml` |
| Custom values (lab-home) | `03-argocd/nexus/helm/custom-values/lab-home.yaml` |
| Helm chart        | `03-argocd/nexus/helm/charts/nexus-repository-manager-64.2.0` |

## Подготовка чарта (один раз)

Чарт берётся из [Sonatype Helm3 Charts](https://github.com/sonatype/helm3-charts). Если каталог `helm/charts/nexus-repository-manager-64.2.0` пуст или отсутствует:

```bash
cd 03-argocd/nexus/helm
helm repo add sonatype https://sonatype.github.io/helm3-charts
helm pull sonatype/nexus-repository-manager --version 64.2.0 --untar -d charts
mv charts/nexus-repository-manager charts/nexus-repository-manager-64.2.0
```

## Развёртывание через ArgoCD

1. Применить Application:
   ```bash
   kubectl apply -f 03-argocd/nexus/application.yaml
   ```

2. Дождаться готовности:
   ```bash
   kubectl get pods -n nexus -w
   ```

3. Доступ: `https://nexus.lab-home.com` (пароль по умолчанию — см. секрет в namespace `nexus`).

## Установка без ArgoCD (Helm)

```bash
helm upgrade --install nexus 03-argocd/nexus/helm/charts/nexus-repository-manager-64.2.0 \
  -n nexus --create-namespace \
  -f 03-argocd/nexus/helm/custom-values/lab-home.yaml
```
