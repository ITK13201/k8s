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

## ブートストラップシークレット

ESO は起動後に Secret を生成するため、以下のシークレットは **ESO で管理できない**。
クラスタ再構築時に手動で適用する必要がある。

| Secret 名 | Namespace | 内容 | 適用タイミング |
|-----------|-----------|------|--------------|
| `1password-credentials` | onepassword | Connect Server の credentials.json | Connect デプロイ前 |
| `onepassword-connect-token` | onepassword | ESO → Connect 認証トークン | Connect デプロイ前 |
| `private-repo-creds` | argocd | GitHub PAT（ArgoCD repo アクセス） | ArgoCD 起動前 |

### ブートストラップコマンド

```bash
# 1. 1Password Connect の credentials.json と token を用意
#    (1Password.com > Integrations > Connect Server で発行)

# 2. namespace 作成
kubectl create namespace onepassword

# 3. Connect Server 認証情報（credentials.json）を Secret として投入
kubectl create secret generic 1password-credentials \
  --from-file=1password-credentials.json=./1password-credentials.json \
  -n onepassword

# 4. ESO が使う Connect API トークン
kubectl create secret generic onepassword-connect-token \
  --from-literal=token=<CONNECT_TOKEN> \
  -n onepassword

# 5. ArgoCD が GitHub repo をクローンするための PAT
kubectl create secret generic private-repo-creds \
  --from-literal=type=git \
  --from-literal=url=https://github.com/ITK13201/k8s.git \
  --from-literal=username=itk13201 \
  --from-literal=password=$(op read "op://K8s-Secrets/k8s/argocd-repo-creds/token") \
  -n argocd \
  --dry-run=client -o yaml \
  | kubectl label --local -f - argocd.argoproj.io/secret-type=repo-creds -o yaml \
  | kubectl apply -f -
```

## デプロイ順序

ESO の ExternalSecret は ClusterSecretStore（Connect）が Ready になるまで失敗し続ける。
ESO は自動リトライするため、ArgoCD で以下の順に同期すれば最終的に全 Secret が生成される。

```
Step 1: kubectl apply（手動）
  ├── 1password-credentials   (onepassword ns)
  ├── onepassword-connect-token (onepassword ns)
  └── private-repo-creds      (argocd ns)

Step 2: ArgoCD sync
  ├── onepassword-connect      ← Connect Server が起動
  └── external-secrets         ← ESO + ClusterSecretStore が起動

Step 3: ArgoCD sync（またはリトライ後に自動完了）
  └── 各アプリの ExternalSecret が Secret を生成
```

初回同期後は Connect が健全な状態になれば ESO が自動的に残りの ExternalSecret を同期する。

## 1Password Vault 構成

```
K8s-Secrets (vault)
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
    ├── mailserver-resend-secret       ← 追加（旧設計書に未記載）
    ├── moneyrabbit-mariadb-secret     ← 追加（旧設計書に未記載）
    ├── moneyrabbit-secret             ← 追加（旧設計書に未記載）
    ├── tailscale-operator-oauth       ← 追加（旧設計書に未記載）
    ├── argocd-repo-creds              ← ブートストラップ専用（ESO 管理外）
    └── ansible-workers-secret
```

各項目は「Login」または「Secure Note」タイプで、フィールド名は既存の .env ファイルのキー名に合わせる。

## ディレクトリ構成（移行後）

```
manifests/
├── external-secrets/           # 新規追加
│   ├── kustomization.yaml      # ESO Helm chart
│   └── cluster-secret-store.yaml
├── onepassword-connect/        # 新規追加
│   ├── kustomization.yaml      # 1Password Connect Helm chart
│   └── namespace.yaml
├── growi/
│   ├── external-secret.yaml    # ExternalSecret CRD（git 管理）
│   └── ...
├── mailserver/
│   ├── external-secret.yaml    # 新規追加
│   └── ...
├── moneyrabbit/
│   ├── external-secret.yaml    # 新規追加
│   └── ...
├── tailscale/
│   ├── external-secret.yaml    # 新規追加（手動作成から ESO 管理へ移行）
│   └── ...
...

credentials/   ← 廃止
secrets/       ← 廃止
bin/create_secrets.sh  ← 廃止
```

## 移行対象一覧

| Namespace | Secret 名 | 対応する .env ファイル | 1Password 項目名 |
|-----------|----------|----------------------|--------------------|
| growi | growi-secret | credentials/growi/growi-secret.env | growi-secret |
| growi | mongodb-secret | credentials/growi/mongodb-secret.env | growi-mongodb-secret |
| palworld | palworld-secrets | credentials/palworld/palworld-secrets.env | palworld-secrets |
| rss-generator | mariadb-secret | credentials/rss-generator/mariadb-secret.env | rss-generator-mariadb-secret |
| rss-generator | rss-generator-secret | credentials/rss-generator/rss-generator-secret.env | rss-generator-secret |
| cert-manager | cloudflare-secret | credentials/cert-manager/cloudflare-secret.env | cert-manager-cloudflare-secret |
| growi-converter | growi-converter-secret | credentials/growi-converter/growi-converter-secret.env | growi-converter-secret |
| nextcloud | mariadb-secret | credentials/nextcloud/mariadb-secret.env | nextcloud-mariadb-secret |
| nextcloud | redis-secret | credentials/nextcloud/redis-secret.env | nextcloud-redis-secret |
| nextcloud | nextcloud-secret | credentials/nextcloud/nextcloud-secret.env | nextcloud-secret |
| minecraft | minecraft-secret | credentials/minecraft/minecraft-secret.env | minecraft-secret |
| minecraft | mariadb-secret | credentials/minecraft/mariadb-secret.env | minecraft-mariadb-secret |
| rss-notifier | mariadb-secret | credentials/rss-notifier/mariadb-secret.env | rss-notifier-mariadb-secret |
| rss-notifier | rss-notifier-secret | credentials/rss-notifier/rss-notifier-secret.env | rss-notifier-secret |
| monitoring | grafana | credentials/monitoring/grafana.env | monitoring-grafana |
| mailserver | mailserver-resend-secret | credentials/mailserver/mailserver-resend-secret.env | mailserver-resend-secret |
| moneyrabbit | moneyrabbit-mariadb-secret | credentials/moneyrabbit/moneyrabbit-mariadb-secret.env | moneyrabbit-mariadb-secret |
| moneyrabbit | moneyrabbit-secret | credentials/moneyrabbit/moneyrabbit-secret.env | moneyrabbit-secret |
| tailscale | operator-oauth | credentials/tailscale/operator-oauth.env | tailscale-operator-oauth |
| (Ansible) | — | ansible/inventory/group_vars/workers/secret.yml | ansible-workers-secret |
| (bootstrap) | private-repo-creds | secrets/argocd/argocd-secret.yaml | argocd-repo-creds |

## マニフェスト例

### 1Password Connect (kustomization.yaml)

```yaml
# manifests/onepassword-connect/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- namespace.yaml
helmCharts:
- name: connect
  repo: https://1password.github.io/connect-helm-charts
  version: 1.16.0
  releaseName: onepassword-connect
  namespace: onepassword
  valuesFile: values.yaml
  valuesMerge: override
```

### External Secrets Operator (kustomization.yaml)

```yaml
# manifests/external-secrets/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- cluster-secret-store.yaml
helmCharts:
- name: external-secrets
  repo: https://charts.external-secrets.io
  version: 0.17.0
  releaseName: external-secrets
  namespace: external-secrets
  valuesFile: values.yaml
  valuesMerge: override
  includeCRDs: true
```

### ClusterSecretStore

```yaml
# manifests/external-secrets/cluster-secret-store.yaml
---
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: onepassword
spec:
  provider:
    onepassword:
      connectHost: http://onepassword-connect.onepassword.svc.cluster.local:8080
      vaults:
        K8s-Secrets: 1
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
---
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

### ExternalSecret（例: tailscale operator-oauth）

```yaml
# manifests/tailscale/external-secret.yaml
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: operator-oauth
  namespace: tailscale
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword
  target:
    name: operator-oauth
    creationPolicy: Owner
  data:
    - secretKey: client_id
      remoteRef:
        key: tailscale-operator-oauth
        property: client_id
    - secretKey: client_secret
      remoteRef:
        key: tailscale-operator-oauth
        property: client_secret
```

## Ansible シークレットの移行

1Password CLI (`op`) を使用して `workers.secret.yml` を生成する。

### テンプレートファイル

```yaml
# ansible/inventory/group_vars/workers/secret.yml.tpl（git 管理対象）
---
server_setup_discord_bot_cli_config_token: "{{ op://K8s-Secrets/ansible-workers-secret/token }}"
server_setup_discord_bot_cli_config_channels:
  - name: system
    id: "{{ op://K8s-Secrets/ansible-workers-secret/channel_system_id }}"
  - name: nextcloud
    id: "{{ op://K8s-Secrets/ansible-workers-secret/channel_nextcloud_id }}"
  - name: growi
    id: "{{ op://K8s-Secrets/ansible-workers-secret/channel_growi_id }}"
```

### 実行方法

```bash
# workers.secret.yml を 1Password から生成
op inject -i ansible/inventory/group_vars/workers/secret.yml.tpl \
          -o ansible/inventory/group_vars/workers/secret.yml
```

## タスク一覧

### 準備（手動）

- [ ] 1Password に `k8s/` vault 配下の項目を作成し、既存 `.env` の値を移行（19項目）
- [ ] 1Password Connect の credentials.json とトークンを発行

### マニフェスト追加

- [ ] `manifests/onepassword-connect/` を追加（Helm chart + namespace）
- [ ] `manifests/external-secrets/` を追加（ESO Helm chart + ClusterSecretStore）

### ExternalSecret 追加（各アプリ）

- [ ] growi（growi-secret, mongodb-secret）
- [ ] palworld（palworld-secrets）
- [ ] cert-manager（cloudflare-secret）
- [ ] growi-converter（growi-converter-secret）
- [ ] nextcloud（mariadb-secret, redis-secret, nextcloud-secret）
- [ ] minecraft（minecraft-secret, mariadb-secret）
- [ ] rss-generator（mariadb-secret, rss-generator-secret）
- [ ] rss-notifier（mariadb-secret, rss-notifier-secret）
- [ ] monitoring（grafana）
- [ ] mailserver（mailserver-resend-secret）
- [ ] moneyrabbit（moneyrabbit-mariadb-secret, moneyrabbit-secret）
- [ ] tailscale（operator-oauth）

### Ansible

- [ ] `workers.secret.yml.tpl` を追加（`op://` 参照テンプレート）
- [ ] `workers.secret.yml.example` を `.tpl` ベースに更新
- [ ] `docs/ansible.md` の手順を更新（`op inject` での生成手順を追記）

### クラスタへの適用

- [ ] ブートストラップシークレット 3 件を手動 apply（`1password-credentials`, `onepassword-connect-token`, `private-repo-creds`）
- [ ] ArgoCD で `onepassword-connect` を同期・Connect が Ready になることを確認
- [ ] ArgoCD で `external-secrets` を同期・ClusterSecretStore が Ready になることを確認
- [ ] 各アプリの ExternalSecret が同期されることを確認（`kubectl get externalsecret -A`）
- [ ] 旧 Secret が ESO 管理の Secret に置き換わったことを確認

### クリーンアップ

- [ ] `credentials/` ディレクトリを削除
- [ ] `secrets/` ディレクトリを削除（ただし `secrets/argocd/argocd-secret.yaml` は削除前にブートストラップ手順に移行済みであることを確認）
- [ ] `bin/create_secrets.sh` を削除
- [ ] `.gitignore` から `credentials/` / `secrets/` エントリを削除
- [ ] `docs/secrets.md` を新フローに更新
- [ ] `CLAUDE.md` の「Secretの再生成」コマンドを更新
- [ ] `manifests/CLAUDE.md` の tailscale 手動作成の注記を更新

## 参考

- [External Secrets Operator](https://external-secrets.io/)
- [1Password Connect](https://developer.1password.com/docs/connect/)
- [ESO 1Password Provider](https://external-secrets.io/latest/provider/1password-automation/)
- [1Password Connect Helm Chart](https://github.com/1Password/connect-helm-charts)
