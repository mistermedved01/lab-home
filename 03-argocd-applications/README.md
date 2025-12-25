# ArgoCD Applications

Эта директория содержит ArgoCD Applications для управления приложениями в Kubernetes кластере через GitOps.

## Структура

```
03-argocd-applications/
├── applications/
│   ├── app-of-apps.yaml             # Root Application (опционально)
│   ├── rancher/
│   │   ├── application.yaml         # ArgoCD Application для Rancher
│   │   └── values.yaml               # Helm values для Rancher (если используется Helm)
│   ├── gitlab/
│   │   ├── application.yaml         # ArgoCD Application для GitLab
│   │   └── values.yaml               # Helm values для GitLab
│   └── ...                          # Другие приложения
├── projects/
│   ├── platform-project.yaml        # ArgoCD Project для платформенных компонентов
│   └── apps-project.yaml            # ArgoCD Project для приложений
└── README.md                         # Этот файл
```

## Предварительные требования

1. ArgoCD должен быть установлен и настроен (см. `02-k8s-argocd-install/`)
2. Доступ к ArgoCD через UI или CLI
3. Настроенные ArgoCD Projects (если используется)

## Планируемые приложения

- **Rancher** - платформа управления Kubernetes
- **GitLab** - CI/CD платформа
- Другие приложения (будут добавлены позже)

## Использование

### Применение ArgoCD Applications

```bash
# Применение всех Applications
kubectl apply -f applications/

# Применение конкретного Application
kubectl apply -f applications/rancher/application.yaml

# Применение Projects
kubectl apply -f projects/
```

### Проверка статуса

```bash
# Список всех Applications
kubectl get applications -n argocd

# Детали Application
kubectl describe application <app-name> -n argocd

# Через ArgoCD CLI
argocd app list
argocd app get <app-name>
```

## App of Apps Pattern

Если используется App of Apps pattern, создайте `applications/app-of-apps.yaml`, который будет управлять всеми остальными Applications.

## Дополнительные ресурсы

- [ArgoCD Applications документация](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#applications)
- [App of Apps pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#app-of-apps-pattern)
- [ArgoCD Projects](https://argo-cd.readthedocs.io/en/stable/user-guide/projects/)

