# シークレット管理

すべてのシークレットを **1Password** で一元管理し、**External Secrets Operator (ESO)** + **1Password Connect** を通じてクラスタに同期する。

設計の詳細は [docs/design/secrets-1password.md](design/secrets-1password.md) を参照。

## アーキテクチャ

```
1Password (SaaS)
    ↓ Connect API
1Password Connect Server  (onepassword namespace)
    ↓ HTTP API
External Secrets Operator (external-secrets namespace)
    ↓ watches ExternalSecret CRD
Kubernetes Secret
    ↓
アプリケーション Pod
```

- `ExternalSecret` マニフェストはリポジトリで管理（GitOps 対応）
- 1Password vault: `K8s-Secrets`
- refreshInterval: 1h（1Password 側の変更が最大1時間でクラスタに反映）

## ブートストラップ手順（クラスタ再構築時）

ESO が稼働する前に必要な3つのシークレットを手動で適用する。

### 1. 1Password Connect 認証情報の準備

1Password.com > Integrations > Connect Server から以下を発行する:
- `1password-credentials.json`（Connect Server 本体の認証ファイル）
- Connect API トークン

### 2. namespace 作成

```bash
kubectl create namespace onepassword
```

### 3. Connect Server の認証情報を Secret として投入

```bash
kubectl create secret generic 1password-credentials \
  --from-file=1password-credentials.json=./1password-credentials.json \
  -n onepassword
```

### 4. ESO が Connect に接続するための API トークンを投入

```bash
kubectl create secret generic onepassword-connect-token \
  --from-literal=token=<CONNECT_TOKEN> \
  -n onepassword
```

### 5. ArgoCD が GitHub repo にアクセスするための PAT を投入

```bash
kubectl create secret generic private-repo-creds \
  --from-literal=type=git \
  --from-literal=url=https://github.com/ITK13201/k8s.git \
  --from-literal=username=itk13201 \
  --from-literal=password=$(op read "op://K8s-Secrets/argocd-repo-creds/token") \
  -n argocd \
  --dry-run=client -o yaml \
  | kubectl label --local -f - argocd.argoproj.io/secret-type=repo-creds -o yaml \
  | kubectl apply -f -
```

### 6. ArgoCD で同期（順序を守ること）

```bash
# 1. 1Password Connect を先にデプロイ
argocd app sync k8s-onepassword-connect

# Connect が Ready になるまで待機
kubectl rollout status deployment/onepassword-connect -n onepassword

# 2. ESO + ClusterSecretStore をデプロイ
argocd app sync k8s-external-secrets

# ClusterSecretStore が Ready になるまで待機
kubectl wait clustersecretstore onepassword --for=condition=Ready --timeout=120s

# 3. 残りのアプリを同期（ESO が ExternalSecret を自動処理）
argocd app sync --selector app.kubernetes.io/instance=k8s
```

### 7. ExternalSecret の同期確認

```bash
kubectl get externalsecret -A
```

すべての ExternalSecret が `SecretSynced` 状態になれば完了。

## 通常運用

### シークレットの値を変更する

1. 1Password の対象 vault 項目の値を更新する
2. 最大 1 時間（`refreshInterval`）で自動反映される
3. 即時反映が必要な場合は ExternalSecret をアノテートして強制リフレッシュ:

```bash
kubectl annotate externalsecret <name> -n <namespace> \
  force-sync=$(date +%s) --overwrite
```

### 新しいアプリのシークレットを追加する

1. 1Password の `K8s-Secrets` vault に新しい項目を作成する
2. `manifests/<app>/external-secret.yaml` を作成する（既存ファイルを参考に）
3. `manifests/<app>/kustomization.yaml` の `resources:` に追加する
4. `git push` → ArgoCD が自動同期

### ExternalSecret のステータス確認

```bash
# 全 namespace の ExternalSecret を一覧表示
kubectl get externalsecret -A

# 詳細（エラー確認）
kubectl describe externalsecret <name> -n <namespace>

# ClusterSecretStore の状態確認
kubectl get clustersecretstore
```

## 1Password vault 項目一覧

| 1Password 項目名 | Namespace | Secret 名 |
|----------------|-----------|----------|
| growi-secret | growi | growi-secret |
| growi-mongodb-secret | growi | mongodb-secret |
| palworld-secrets | palworld | palworld-secrets |
| rss-generator-mariadb-secret | rss-generator | mariadb-secret |
| rss-generator-secret | rss-generator | rss-generator-secret |
| cert-manager-cloudflare-secret | cert-manager | cloudflare-secret |
| growi-converter-secret | growi-converter | growi-converter-secret |
| nextcloud-mariadb-secret | nextcloud | mariadb-secret |
| nextcloud-redis-secret | nextcloud | redis-secret |
| nextcloud-secret | nextcloud | nextcloud-secret |
| minecraft-secret | minecraft | minecraft-secret |
| minecraft-mariadb-secret | minecraft | mariadb-secret |
| rss-notifier-mariadb-secret | rss-notifier | mariadb-secret |
| rss-notifier-secret | rss-notifier | rss-notifier-secret |
| monitoring-grafana | monitoring | grafana |
| mailserver-resend-secret | mailserver | mailserver-resend-secret |
| moneyrabbit-mariadb-secret | moneyrabbit | moneyrabbit-mariadb-secret |
| moneyrabbit-secret | moneyrabbit | moneyrabbit-secret |
| tailscale-operator-oauth | tailscale | operator-oauth |
| argocd-repo-creds | argocd | private-repo-creds（bootstrap のみ） |
| ansible-workers-secret | —（Ansible） | workers.secret.yml |

## Ansible シークレット

Ansible の `workers.secret.yml` は 1Password CLI (`op`) で生成する。

```bash
op inject -i ansible/inventory/group_vars/workers/secret.yml.tpl \
          -o ansible/inventory/group_vars/workers/secret.yml
```

詳細は [docs/ansible.md](ansible.md) を参照。
