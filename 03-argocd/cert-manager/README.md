# cert-manager

cert-manager автоматизирует выпуск и обновление TLS-сертификатов в Kubernetes: Ingress, Certificate, webhook’и. Приложениям достаточно указать ClusterIssuer — дальше cert-manager сам выпускает Secret с `tls.crt` / `tls.key` и продлевает его до истечения.

Схема:

- cert-manager (Helm) — controller + webhook + cainjector, **1 реплика** каждый
- CRDs — `installCRDs: true`
- PKI lab: `selfsigned-issuer` → CA Certificate `lab-home-root-ca` → ClusterIssuer `lab-home-ca-issuer`
- Приложения — аннотация Ingress / `issuerRef` на **`lab-home-ca-issuer`**

| | |
|---|---|
| Namespace | `cert-manager` |
| Replicas | controller / webhook / cainjector: `1` |
| CRDs | `installCRDs: true` |
| Issuer (bootstrap) | ClusterIssuer `selfsigned-issuer` |
| Issuer (lab) | ClusterIssuer `lab-home-ca-issuer` |
| CA | Certificate + Secret `lab-home-root-ca` (ns `cert-manager`) |
| Chart | `helm/charts/cert-manager-1.16.0` |

Argo синкает **только Helm**. ClusterIssuer и Certificate CA **не** входят в Application — их нет в кластере, пока не примените вручную.

## Предварительные требования

1. ArgoCD
2. Kubernetes **>= 1.22**

ingress-nginx нужен приложениям с TLS на Ingress, самому cert-manager — нет.

## Структура

```
cert-manager/
├── application.yaml
├── clusterissuer-selfsigned.yaml   # kubectl (не Argo)
├── helm/
│   ├── charts/cert-manager-1.16.0/
│   └── custom-values/lab-home.yaml
└── README.md
```

## Развёртывание

```bash
kubectl apply -f 03-argocd/cert-manager/application.yaml
kubectl -n argocd get application cert-manager
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s
kubectl get pods,crd -n cert-manager
```

Дождаться Running у `cert-manager`, `cert-manager-webhook`, `cert-manager-cainjector` и появления CRD (`certificates.cert-manager.io`, `clusterissuers.cert-manager.io`, …).

## PKI (lab)

Цепочка: self-signed ClusterIssuer подписывает корневой CA, CA-issuer подписывает сертификаты приложений. Без `lab-home-ca-issuer` Ingress с аннотацией `cert-manager.io/cluster-issuer: lab-home-ca-issuer` не станет Ready.

### 1) selfsigned-issuer

```bash
kubectl apply -f 03-argocd/cert-manager/clusterissuer-selfsigned.yaml
kubectl get clusterissuer selfsigned-issuer
```

### 2) корневой CA

Secret должен лежать в namespace `cert-manager` (туда смотрит ClusterIssuer).

```bash
kubectl apply -f - <<'EOF'
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: lab-home-root-ca
  namespace: cert-manager
spec:
  isCA: true
  commonName: lab-home-root-ca
  secretName: lab-home-root-ca
  privateKey:
    algorithm: RSA
    size: 2048
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
    group: cert-manager.io
EOF
kubectl -n cert-manager get certificate lab-home-root-ca
```

Без `duration` cert-manager ставит **90 дней**. Для lab-CA лучше задать явно, иначе раз в квартал ротация корня и нужно обновлять trust на клиентах/нодах:

```yaml
  duration: 87600h      # 10 лет
  renewBefore: 2160h    # 90 дней
```

### 3) lab-home-ca-issuer

```bash
kubectl apply -f - <<'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: lab-home-ca-issuer
spec:
  ca:
    secretName: lab-home-root-ca
EOF
kubectl get clusterissuer lab-home-ca-issuer
```

Ready: `Signing CA verified`.

## Использование в приложениях

Ingress:

```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: lab-home-ca-issuer
spec:
  tls:
    - hosts: [app.lab-home.com]
      secretName: app-tls
```

Или отдельный Certificate (`issuerRef.name: lab-home-ca-issuer`, `kind: ClusterIssuer`) — как у Vault/GitLab.

Сначала cert-manager + оба ClusterIssuer Ready, потом приложения с TLS.

## Доверие CA на клиенте

Без импорта корня браузер и CLI ругаются на «недоверенный ЦС».

```bash
kubectl get secret lab-home-root-ca -n cert-manager \
  -o jsonpath='{.data.ca\.crt}' | base64 -d > lab-home-ca.crt
```

Windows (PowerShell от администратора):

```powershell
certutil -addstore Root C:\path\to\lab-home-ca.crt
```

После ротации CA (истёк / перевыпущен `lab-home-root-ca`) заново импортировать корень на ПК и в trust store нод (containerd/Harbor). Подробнее: [`EDGE-NETWORK.md`](../../EDGE-NETWORK.md).

## Проверка

```bash
kubectl get pods -n cert-manager
kubectl get clusterissuer
kubectl get certificate -A
kubectl describe certificate <name> -n <ns>
kubectl describe certificaterequest -n <ns>
```

## Частые проблемы

```bash
# поды не Ready
kubectl get events -n cert-manager --sort-by='.lastTimestamp'
kubectl logs -n cert-manager -l app.kubernetes.io/instance=cert-manager

# ClusterIssuer не Ready
kubectl describe clusterissuer lab-home-ca-issuer
kubectl -n cert-manager get secret lab-home-root-ca

# Certificate не Ready (часто: issuer ещё не было)
kubectl describe certificate <name> -n <ns>
kubectl get certificaterequest -A
```

Приложение задеплоили раньше issuer — Certificate остаётся `False`, пока issuer Ready; после этого cert-manager обычно догоняет сам. Если нет — удалить Certificate, чтобы контроллер создал заново.

## Let's Encrypt (не lab)

Lab живёт на внутреннем CA. ACME/Let's Encrypt нужен только если сервис торчит в интернет с публичным DNS. Пример issuer — в документации [cert-manager ACME](https://cert-manager.io/docs/configuration/acme/).

## Апгрейд chart

Один chart в git: `helm/charts/cert-manager-1.16.0`. Path в `application.yaml`. Перед сменой версии — breaking changes values и CRDs (`installCRDs: true` обновляет CRD вместе с релизом).
