# Vault

Raft, 1 реплика. Внутренний TLS и Ingress — cert-manager (`lab-home-ca-issuer`). CronJob бэкапа в том же Argo Application.

## 1. Namespace + секреты бэкапа

Argo секреты не создаёт. CronJob без них будет Unhealthy, но Vault поднимется.

```bash
kubectl create namespace vault --dry-run=client -o yaml | kubectl apply -f -

# если ещё нет локальных файлов — скопировать из example и заполнить
kubectl apply -f 03-argocd/vault/manifests/minio-s3-ca.yaml
kubectl apply -f 03-argocd/vault/manifests/vault-backup-s3-creds.yaml
# AppRole-секрет — после init, шаг 4; пока можно не трогать
```

В MinIO-консоли создать bucket **`vault-backup`**.

## 2. Application

```bash
kubectl apply -f 03-argocd/vault/application.yaml
kubectl -n argocd get application vault
kubectl get certificate,pods,pvc,ingress -n vault
```

Дождаться `vault-tls` / `vault-injector-tls` Ready и пода `vault-0` Running (ещё sealed).

## 3. Init + unseal

Один раз, ключи сохранить.

```bash
kubectl exec -it vault-0 -n vault -- vault operator init -key-shares=1 -key-threshold=1
kubectl exec -it vault-0 -n vault -- vault operator unseal '<Unseal Key>'
kubectl exec -it vault-0 -n vault -- vault status
```

UI: https://vault.lab-home.com

## 4. AppRole для бэкапа + секрет

В поде уже задан `VAULT_CACERT`:

```bash
kubectl exec -it vault-0 -n vault -- sh
vault login   # root token
echo 'path "sys/storage/raft/snapshot" { capabilities = ["read"] }' | vault policy write snapshot -
vault auth enable approle
vault write auth/approle/role/snapshot-agent token_ttl=2h token_policies=snapshot
vault read auth/approle/role/snapshot-agent/role-id
vault write -f auth/approle/role/snapshot-agent/secret-id
```

Вписать role_id/secret_id в `vault-backup-agent-snapshot-token.yaml` и:

```bash
kubectl apply -f 03-argocd/vault/manifests/vault-backup-agent-snapshot-token.yaml
```

## 5. Проверить бэкап

Не ждать 01:00:

```bash
kubectl create job -n vault vault-backup-manual --from=cronjob/vault-backup-cronjob
kubectl logs -n vault job/vault-backup-manual -c snapshot -f
kubectl logs -n vault job/vault-backup-manual -c upload -f
```

Пока нет AppRole-секрета, CronJob в Argo может быть Degraded — на сам Vault это не влияет. После шага 4 станет нормально.

После рестарта пода Vault снова sealed — повторить unseal.
