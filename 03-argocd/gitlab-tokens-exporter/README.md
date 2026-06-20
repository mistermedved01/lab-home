# GitLab tokens exporter

Prometheus-экспортер срока действия GitLab access token — [cnieg/gitlab-tokens-exporter](https://github.com/cnieg/gitlab-tokens-exporter).

Деплоится в namespace `gitlab` (рядом с GitLab API). Образ: `harbor.lab-home.com/gitlab/gitlab-tokens-exporter`.

## Структура

```text
gitlab-tokens-exporter/
├── application.yaml
├── README.md
└── helm/
    ├── charts/gitlab-tokens-exporter-0.1.0/
    │   ├── Chart.yaml
    │   ├── values.yaml          # дефолты
    │   ├── files/
    │   └── templates/
    └── custom-values/
        └── lab-home.yaml        # lab-home overlay
```

## Предварительные требования

1. GitLab доступен (`https://gitlab.lab-home.com`).
2. Secret с GitLab token в namespace `gitlab`:

```bash
kubectl create secret generic gitlab-tokens-exporter -n gitlab \
  --from-literal=token='<GITLAB_ACCESS_TOKEN>' \
  --dry-run=client -o yaml | kubectl apply -f -
```

`externalSecrets.enabled: false` в `lab-home.yaml` — токен не из Vault/ESO.

## Установка (Argo CD)

```bash
kubectl apply -f 03-argocd/gitlab-tokens-exporter/application.yaml
```

## Установка (Helm, без Argo CD)

```bash
helm upgrade --install gitlab-tokens-exporter \
  03-argocd/gitlab-tokens-exporter/helm/charts/gitlab-tokens-exporter-0.1.0 \
  --namespace gitlab \
  --create-namespace \
  -f 03-argocd/gitlab-tokens-exporter/helm/custom-values/lab-home.yaml
```

## Проверка

```bash
helm lint 03-argocd/gitlab-tokens-exporter/helm/charts/gitlab-tokens-exporter-0.1.0 \
  -f 03-argocd/gitlab-tokens-exporter/helm/custom-values/lab-home.yaml

kubectl -n gitlab logs deploy/gitlab-tokens-exporter --tail=50
kubectl -n gitlab port-forward svc/gitlab-tokens-exporter 13000:3000
curl -s localhost:13000/metrics | head
```
