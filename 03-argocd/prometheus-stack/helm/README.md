# Helm chart для Prometheus Stack

- **ArgoCD** разворачивает чарт из `charts/kube-prometheus-stack-81.6.0/` с values из `custom-values/lab-home.yaml` (см. `../application.yaml`).
- **Обновление версии чарта**: измените версию в `Chart.yaml` (dependencies), выполните `helm dependency update`, затем распакуйте `charts/kube-prometheus-stack-*.tgz` в `charts/kube-prometheus-stack-<version>/` и при необходимости обновите путь в `../application.yaml`.
