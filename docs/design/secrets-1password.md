# シークレット管理 1Password 移行設計書

## 背景・課題

現在のシークレット管理は以下の課題を抱えている。

- `credentials/` ディレクトリにプレーンテキストの `.env` ファイルをローカルに保持する必要がある
- 複数マシン間でのシークレット共有が困難（手動コピーが必要）
- クラスタ再構築時に `credentials/` を別途用意しなければならない
- Ansible 用シークレット（`workers.secret.yml`）も同様の問題を持つ
- シークレットの変更履歴・監査ログがない

## 目標

- すべてのシークレットを 1Password で一元管理する
- `credentials/` ディレクトリを廃止し、ローカルにプレーンテキストを残さない
- ArgoCD (GitOps) のフローを維持しつつ、ExternalSecret CRD をリポジトリで管理する
- Ansible シークレットも 1Password から注入できるようにする

## アーキテクチャ選定

### 採用: External Secrets Operator + 1Password Connect

```
1Password (SaaS)
    ↓ Connect API
1Password Connect Server (Kubernetes Pod)
    ↓ HTTP API
External Secrets Operator
    ↓ watches ExternalSecret CRD
Kubernetes Secret
    ↓
アプリケーション Pod
```

#### 採用理由

| 項目 | ESO + 1Password Connect | 1Password Operator | op CLI |
|------|------------------------|-------------------|--------|
| GitOps 適合性 | ◎ ExternalSecret を git 管理可 | ○ OnePasswordItem CRD | △ |
| 自動ローテーション | ◎ refreshInterval 設定可 | ◎ | △ |
| ベンダー非依存 | ◎ バックエンド変更が容易 | × 1Password 専用 | - |
| 実績・ドキュメント | ◎ | ○ | ◎ |

#### 各コンポーネントの役割

| コンポーネント | 用途 |
|--------------|------|
| **1Password Connect Server** | クラスタ内で動作し、1Password SaaS API のプロキシとして機能 |
| **External Secrets Operator (ESO)** | ExternalSecret CRD を監視し、K8s Secret に同期 |
| **ClusterSecretStore** | ESO が 1Password Connect に接続するための設定 |
| **ExternalSecret** | 1Password の項目と K8s Secret のマッピング（git 管理対象） |

## 1Password Vault 構成

```
Personal (vault)
└── k8s/
    ├── growi-secret
    ├── growi-mongodb-secret
    ├── palworld-secrets
    ├── rss-generator-mariadb-secret
    ├── rss-generator-secret
    ├── cert-manager-cloudflare-secret
    ├── growi-converter-secret
    ├── nextcloud-mariadb-secret
    ├── nextcloud-redis-secret
    ├── nextcloud-secret
    ├── minecraft-secret
    ├── minecraft-mariadb-secret
    ├── rss-notifier-mariadb-secret
    ├── rss-notifier-secret
    ├── monitoring-grafana
    └── ansible-workers-secret      ← Ansible 用
```

各項目は「Login」または「Secure Note」タイプで、フィールド名は既存の env ファイルのキー名に合わせる。

## ディレクトリ構成（移行後）

```
manifests/
├── external-secrets/           # 新規追加
│   └── kustomization.yaml      # ESO Helm chart
├── onepassword-connect/        # 新規追加
│   └── kustomization.yaml      # 1Password Connect Helm chart
├── growi/
│   ├── external-secret.yaml    # ExternalSecret CRD（git 管理）
│   └── ...
├── monitoring/
│   ├── external-secret.yaml
│   └── ...
...

credentials/   ← 廃止
secrets/       ← 廃止
bin/create_secrets.sh  ← 廃止
```

## マニフェスト例

### ClusterSecretStore

```yaml
# manifests/external-secrets/cluster-secret-store.yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: onepassword
spec:
  provider:
    onepassword:
      connectHost: http://onepassword-connect.onepassword.svc.cluster.local:8080
      vaults:
        Personal: 1
      auth:
        secretRef:
          connectTokenSecretRef:
            name: onepassword-connect-token
            namespace: onepassword
            key: token
```

### ExternalSecret（例: growi）

```yaml
# manifests/growi/external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: growi-secret
  namespace: growi
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword
  target:
    name: growi-secret
    creationPolicy: Owner
  data:
    - secretKey: MONGO_URI
      remoteRef:
        key: growi-secret
        property: MONGO_URI
    - secretKey: PASSWORD_SEED
      remoteRef:
        key: growi-secret
        property: PASSWORD_SEED
```

## Ansible シークレットの移行

1Password CLI (`op`) を使用して `workers.secret.yml` を生成する。

### テンプレートファイル

```yaml
# ansible/inventory/group_vars/workers.secret.yml.tpl（git 管理対象）
---
server_setup_discord_bot_cli_config_token: "{{ op://Personal/ansible-workers-secret/token }}"
server_setup_discord_bot_cli_config_channels:
  - name: system
    id: "{{ op://Personal/ansible-workers-secret/channel_system_id }}"
  - name: nextcloud
    id: "{{ op://Personal/ansible-workers-secret/channel_nextcloud_id }}"
  - name: growi
    id: "{{ op://Personal/ansible-workers-secret/channel_growi_id }}"
```

### 実行方法

```bash
# workers.secret.yml を 1Password から生成
op inject -i ansible/inventory/group_vars/workers.secret.yml.tpl \
          -o ansible/inventory/group_vars/workers.secret.yml

# または op run で直接実行（環境変数経由）
op run -- ansible-playbook playbooks/site.yml
```

## 初期セットアップ手順

1. 1Password に `k8s/` vault 項目を作成し、既存の `.env` ファイルの値を移行
2. 1Password Connect の認証情報（Connect Server 認証トークン + credentials.json）を取得
3. Connect トークンを K8s Secret として手動で適用（ブートストラップのみ）：
   ```bash
   kubectl create secret generic onepassword-connect-token \
     --from-literal=token=<TOKEN> \
     -n onepassword
   ```
4. ArgoCD で `onepassword-connect` / `external-secrets` アプリを同期
5. `ClusterSecretStore` が Ready になることを確認
6. 各アプリの `ExternalSecret` が同期されることを確認
7. 旧シークレット（`kubectl apply -R -f secrets/`）を削除
8. `credentials/`・`secrets/` ディレクトリを削除

## 移行対象一覧

| Namespace | Secret 名 | 対応する .env ファイル |
|-----------|----------|----------------------|
| growi | growi-secret | credentials/growi/growi-secret.env |
| growi | mongodb-secret | credentials/growi/mongodb-secret.env |
| palworld | palworld-secrets | credentials/palworld/palworld-secrets.env |
| rss-generator | mariadb-secret | credentials/rss-generator/mariadb-secret.env |
| rss-generator | rss-generator-secret | credentials/rss-generator/rss-generator-secret.env |
| cert-manager | cloudflare-secret | credentials/cert-manager/cloudflare-secret.env |
| growi-converter | growi-converter-secret | credentials/growi-converter/growi-converter-secret.env |
| nextcloud | mariadb-secret | credentials/nextcloud/mariadb-secret.env |
| nextcloud | redis-secret | credentials/nextcloud/redis-secret.env |
| nextcloud | nextcloud-secret | credentials/nextcloud/nextcloud-secret.env |
| minecraft | minecraft-secret | credentials/minecraft/minecraft-secret.env |
| minecraft | mariadb-secret | credentials/minecraft/mariadb-secret.env |
| rss-notifier | mariadb-secret | credentials/rss-notifier/mariadb-secret.env |
| rss-notifier | rss-notifier-secret | credentials/rss-notifier/rss-notifier-secret.env |
| monitoring | grafana | credentials/monitoring/grafana.env |
| (Ansible) | workers.secret.yml | ansible/inventory/group_vars/workers.secret.yml |

## 参考

- [External Secrets Operator](https://external-secrets.io/)
- [1Password Connect](https://developer.1password.com/docs/connect/)
- [ESO 1Password Provider](https://external-secrets.io/latest/provider/1password-automation/)
