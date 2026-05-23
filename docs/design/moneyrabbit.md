# MoneyRabbit デプロイ設計書

## 1. 概要

[MoneyRabbit](https://github.com/ITK13201/MoneyRabbit) は個人用家計管理PWAアプリ。
銀行CSVのインポート・自動カテゴリ分類（Claude Haiku API利用）・月次集計ダッシュボードを提供する。

公式Helm chart（`https://itk13201.github.io/MoneyRabbit`）を使用してデプロイする。
Tailscale Operatorで提供するIngressClassを使い、Tailnetのみからアクセス可能にする（公開しない）。

## 2. コンポーネント構成

| コンポーネント | 技術 | イメージ | ポート |
|--------------|------|---------|--------|
| frontend | React 19 + Vite → Nginx | `ghcr.io/itk13201/moneyrabbit-frontend` | 3000 |
| backend | Go 1.26 + Gin | `ghcr.io/itk13201/moneyrabbit-backend` | 8080 |
| mariadb | MariaDB 11.4 | `mariadb:11.4` | 3306（cluster内部のみ） |

コンテナイメージはMoneyRabbitリポジトリのGitHub Actionsでビルド・GHCRにpushされる。

## 3. アーキテクチャ

```
Tailnetクライアント（VPN接続済み端末）
    ↓ HTTPS (MagicDNS: moneyrabbit.<tailnet>.ts.net)
Tailscale Operator（IngressClass: tailscale）
    ├── /api/*   → backend-svc:8080
    ├── /docs/*  → backend-svc:8080 (Swagger UI)
    └── /        → frontend-svc:3000
                         ↓ HTTP
                    backend Pod
                         ↓ TCP 3306
                    mariadb StatefulSet
                    (PV: /mnt/hdd/data/k8s/pv/moneyrabbit/mariadb)
```

Tailscale IngressはTailnetのMagicDNSで名前解決される。公開インターネットには露出しない。
Cloudflare DNSへの追加・cert-managerによる証明書発行は不要。

**前提**: Tailscale Operatorがクラスタにデプロイ済みであること（「7. Tailscale Operator設定」参照）。

## 4. ストレージ設計

| リソース | 容量 | ホストパス | storageClass | reclaimPolicy |
|---------|------|-----------|-------------|---------------|
| mariadb PV | 20Gi | `/mnt/hdd/data/k8s/pv/moneyrabbit/mariadb` | manual | Retain |

データサイズが増加しうるためHDDに配置する（`/mnt/hdd/`プレフィックス）。

## 5. シークレット設計

ESO + 1Password Connect は未導入のため、`credentials/` ディレクトリ方式で手動管理する。

```
credentials/moneyrabbit/
├── moneyrabbit-secret.env          # gitignore対象
└── moneyrabbit-mariadb-secret.env  # gitignore対象
```

```bash
# credentials/moneyrabbit/moneyrabbit-secret.env
ANTHROPIC_API_KEY=<Claude APIキー>
DATABASE_URL=moneyrabbit:<MYSQL_PASSWORD>@tcp(moneyrabbit-mariadb:3306)/moneyrabbit?parseTime=true
```

```bash
# credentials/moneyrabbit/moneyrabbit-mariadb-secret.env
MYSQL_ROOT_PASSWORD=<rootパスワード>
MYSQL_PASSWORD=<アプリ用パスワード>
MYSQL_USER=moneyrabbit
MYSQL_DATABASE=moneyrabbit
```

`./bin/create_secrets.sh` でSecretマニフェストを生成し、手動でapplyする（ArgoCDは管理しない）:

```bash
./bin/create_secrets.sh
kubectl apply -f secrets/moneyrabbit/
```

v0.2.0から`existingSecret`フィールドでSecretを直接指定できるため、Kustomizeパッチによる差し替えは不要。

> ESO + 1Password移行後は`credentials/moneyrabbit/`を廃止し、`external-secret.yaml`に置き換える（[シークレット管理1Password移行設計](secrets-1password.md)参照）。

## 6. マニフェスト構成

```
manifests/
├── namespaces/
│   └── moneyrabbit.yaml         # Namespace追加
├── pv/
│   ├── kustomization.yaml       # moneyrabbit-mariadb.yaml を追加
│   └── moneyrabbit-mariadb.yaml # 新規作成
└── moneyrabbit/
    ├── kustomization.yaml       # helmCharts のみ
    ├── values.yaml              # Helm values
    └── ingress-tailscale.yaml   # Tailscale Ingress
```

Secretは`credentials/`方式で手動管理するため`external-secret.yaml`は不要。
`manifests/ingress/moneyrabbit.yaml`も不要（ingress-nginxは使用しない）。

### kustomization.yaml

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: moneyrabbit
resources:
- ingress-tailscale.yaml
helmCharts:
- name: moneyrabbit
  repo: https://itk13201.github.io/MoneyRabbit
  version: 0.5.0
  releaseName: moneyrabbit
  namespace: moneyrabbit
  valuesFile: values.yaml
  valuesMerge: override
```

v0.2.0からchartがnamespaceを自前で設定するため、namespaceパッチは不要。
`existingSecret`によるSecretKeyRef対応でpatchesセクションも不要。

### values.yaml

```yaml
---
frontend:
  image:
    tag: "1.0.2"

backend:
  image:
    tag: "1.0.2"
  existingSecret: moneyrabbit-secret   # DATABASE_URL, ANTHROPIC_API_KEY を含む

mariadb:
  auth:
    existingSecret: moneyrabbit-mariadb-secret  # MYSQL_ROOT_PASSWORD, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE を含む
  persistence:
    enabled: true
    storageClass: manual
    size: 20Gi
```

### ingress-tailscale.yaml

```yaml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: moneyrabbit
  namespace: moneyrabbit
spec:
  ingressClassName: tailscale
  rules:
  - http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: moneyrabbit-backend
            port:
              number: 8080
      - path: /docs
        pathType: Prefix
        backend:
          service:
            name: moneyrabbit-backend
            port:
              number: 8080
      - path: /
        pathType: Prefix
        backend:
          service:
            name: moneyrabbit-frontend
            port:
              number: 3000
  tls:
  - hosts:
    - moneyrabbit
```

TLSはTailscale Operatorが自動で終端する（cert-manager不要）。
MagicDNS名は`moneyrabbit.<tailnet>.ts.net`（またはMagicDNSでは`moneyrabbit`のみ）。

### manifests/pv/moneyrabbit-mariadb.yaml

```yaml
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: moneyrabbit-mariadb-pv
  labels:
    target-app: moneyrabbit-mariadb
spec:
  capacity:
    storage: 20Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  local:
    path: /mnt/hdd/data/k8s/pv/moneyrabbit/mariadb
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: Exists
```

## 7. Tailscale Operator設定

Tailscale Operatorはクラスタ全体で1つデプロイするため、`manifests/tailscale/`として独立したアプリとして管理する。

### 前提条件

Tailscaleアカウントの管理コンソールで**OAuthクライアント**を作成し、以下を取得すること。

| 項目 | 内容 |
|------|------|
| Client ID | `tskey-client-...` |
| Client Secret | `...` |
| スコープ | `devices:write`（Operator用） |

### マニフェスト構成

```
manifests/tailscale/
├── kustomization.yaml
├── values.yaml
└── external-secret.yaml
```

```yaml
# kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: tailscale
resources:
- external-secret.yaml
helmCharts:
- name: tailscale-operator
  repo: https://pkgs.tailscale.com/helmcharts
  version: 1.84.0   # helm show values tailscale-operator --repo https://pkgs.tailscale.com/helmcharts で最新を確認
  releaseName: tailscale-operator
  namespace: tailscale
  valuesFile: values.yaml
  valuesMerge: override
```

```yaml
# values.yaml
---
operatorConfig:
  defaultTags:
  - tag:k8s
oauth:
  clientId: "PLACEHOLDER"       # Kustomizeパッチで差し替え（またはESO経由）
  clientSecret: "PLACEHOLDER"   # Kustomizeパッチで差し替え（またはESO経由）
```

OAuthクライアント情報は1Password Vault `Personal/k8s/tailscale-operator-secret`に保存し、ESOで同期する。

### Namespace追加

`manifests/namespaces/tailscale.yaml`を作成し、`kustomization.yaml`に追加する。

## 8. Ansible PVディレクトリ追加

`ansible/inventory/group_vars/workers/main.yml`の`server_setup_k8s_pv_dirs` HDDセクションに追加する。

```yaml
server_setup_k8s_pv_dirs:
  hdd:
    # 既存エントリ...
    - /mnt/hdd/data/k8s/pv/moneyrabbit/mariadb
```

## 9. リソース見積もり

| コンポーネント | CPU request | RAM request |
|--------------|-------------|-------------|
| frontend | 50m | 64Mi |
| backend | 100m | 128Mi |
| mariadb | 200m | 512Mi |
| **合計** | **350m** | **704Mi** |

## 10. 実装手順

1. **Tailscale Operator導入**（未導入の場合）
   - Tailscale管理コンソールでOAuthクライアントを作成
   - `manifests/tailscale/`・`manifests/namespaces/tailscale.yaml`を作成
   - `master`にpush → ArgoCDで同期・IngressClass`tailscale`が作成されることを確認

2. **Secretの手動作成**
   - `credentials/moneyrabbit/moneyrabbit-secret.env`を作成
   - `credentials/moneyrabbit/moneyrabbit-mariadb-secret.env`を作成
   - `mkdir -p secrets/moneyrabbit/ && ./bin/create_secrets.sh`
   - `kubectl apply -f secrets/moneyrabbit/`（Namespace作成後に実行）

3. **Ansible変数追加→ディレクトリ作成**
   - `server_setup_k8s_pv_dirs`にMariaDB HDDパスを追記
   - `ansible-playbook playbooks/workers.yml`でディレクトリ作成

4. **マニフェスト作成・ローカル検証**
   - 上記のマニフェストを作成
   - `kustomize build --enable-helm ./manifests/moneyrabbit/`でレンダリングを確認

5. **pushとArgoCDデプロイ**
   - `master`にpush → ArgoCDが自動同期（Secretは手順2で適用済みであること）

6. **動作確認**
   - `kubectl get pods -n moneyrabbit`で全PodがReadyになるまで確認
   - Tailscale VPN接続済みの端末で`https://moneyrabbit.<tailnet>.ts.net`にアクセス
   - CSVインポート・カテゴリ分類・ダッシュボード表示を確認

## 11. 進捗

| フェーズ | ステータス |
|---------|----------|
| 設計書作成 | ✅ 完了 |
| Tailscale Operator導入 | ⏳ 未実施 |
| Secret手動作成 | ⏳ 未実施 |
| Ansible PVディレクトリ追加 | ⏳ 未実施 |
| マニフェスト作成・ローカル検証 | ✅ 完了 |
| 本番デプロイ・動作確認 | ⏳ 未実施 |
