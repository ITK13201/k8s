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

1Password Vault `Personal/k8s/`に以下の項目を追加する。

| 1Password項目名 | フィールド | 用途 |
|----------------|----------|------|
| `moneyrabbit-mariadb-secret` | `MARIADB_ROOT_PASSWORD` | MariaDB root認証 |
| `moneyrabbit-mariadb-secret` | `MARIADB_PASSWORD` | アプリ用MariaDBユーザー認証 |
| `moneyrabbit-secret` | `ANTHROPIC_API_KEY` | Claude Haiku API |

ESOのExternalSecretでK8s Secretに同期する。

HelmチャートはAPIキーとパスワードをvalues.yamlの平文で受け取る設計になっているため、Kustomizeのstrategic merge patchでSecretKeyRefに差し替える（詳細は「6. マニフェスト構成」参照）。

## 6. マニフェスト構成

```
manifests/
├── namespaces/
│   └── moneyrabbit.yaml         # Namespace追加
├── pv/
│   ├── kustomization.yaml       # moneyrabbit-mariadb.yaml を追加
│   └── moneyrabbit-mariadb.yaml # 新規作成
└── moneyrabbit/
    ├── kustomization.yaml       # helmCharts + patches
    ├── values.yaml              # Helm values（非シークレット設定）
    ├── external-secret.yaml     # 1Password ESO連携
    └── ingress-tailscale.yaml   # Tailscale Ingress
```

> `manifests/ingress/moneyrabbit.yaml` は不要（ingress-nginxは使用しない）。

### kustomization.yaml

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: moneyrabbit
resources:
- external-secret.yaml
- ingress-tailscale.yaml
helmCharts:
- name: moneyrabbit
  repo: https://itk13201.github.io/MoneyRabbit
  version: 0.1.0
  releaseName: moneyrabbit
  namespace: moneyrabbit
  valuesFile: values.yaml
  valuesMerge: override
patches:
# kustomize helmChartsにnamespaceが適用されない制約を回避
- patch: '[{"op":"add","path":"/metadata/namespace","value":"moneyrabbit"}]'
  target:
    kind: Deployment
- patch: '[{"op":"add","path":"/metadata/namespace","value":"moneyrabbit"}]'
  target:
    kind: StatefulSet
- patch: '[{"op":"add","path":"/metadata/namespace","value":"moneyrabbit"}]'
  target:
    kind: Service
- patch: '[{"op":"add","path":"/metadata/namespace","value":"moneyrabbit"}]'
  target:
    kind: PersistentVolumeClaim
# ANTHROPIC_API_KEY をSecretKeyRefに差し替え
- target:
    kind: Deployment
    name: moneyrabbit-backend
  patch: |
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: moneyrabbit-backend
    spec:
      template:
        spec:
          containers:
          - name: backend
            env:
            - name: ANTHROPIC_API_KEY
              valueFrom:
                secretKeyRef:
                  name: moneyrabbit-secret
                  key: ANTHROPIC_API_KEY
# MariaDBパスワードをSecretKeyRefに差し替え
- target:
    kind: StatefulSet
    name: moneyrabbit-mariadb
  patch: |
    apiVersion: apps/v1
    kind: StatefulSet
    metadata:
      name: moneyrabbit-mariadb
    spec:
      template:
        spec:
          containers:
          - name: mariadb
            env:
            - name: MARIADB_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: moneyrabbit-mariadb-secret
                  key: MARIADB_ROOT_PASSWORD
            - name: MARIADB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: moneyrabbit-mariadb-secret
                  key: MARIADB_PASSWORD
```

> **注意**: strategic merge patchのenv差し替えはenv名をマージキーとして使う。実際の動作は`kustomize build --enable-helm ./manifests/moneyrabbit/`で検証すること。

### values.yaml

```yaml
---
frontend:
  image:
    tag: "1.0.2"

backend:
  image:
    tag: "1.0.2"
  anthropicApiKey: "PLACEHOLDER"  # Kustomizeパッチで差し替え

mariadb:
  auth:
    password: "PLACEHOLDER"       # Kustomizeパッチで差し替え
    rootPassword: "PLACEHOLDER"   # Kustomizeパッチで差し替え
  persistence:
    enabled: true
    storageClass: manual
    size: 20Gi
```

### external-secret.yaml

```yaml
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: moneyrabbit-secret
  namespace: moneyrabbit
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword
  target:
    name: moneyrabbit-secret
    creationPolicy: Owner
  data:
  - secretKey: ANTHROPIC_API_KEY
    remoteRef:
      key: moneyrabbit-secret
      property: ANTHROPIC_API_KEY
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: moneyrabbit-mariadb-secret
  namespace: moneyrabbit
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword
  target:
    name: moneyrabbit-mariadb-secret
    creationPolicy: Owner
  data:
  - secretKey: MARIADB_ROOT_PASSWORD
    remoteRef:
      key: moneyrabbit-mariadb-secret
      property: MARIADB_ROOT_PASSWORD
  - secretKey: MARIADB_PASSWORD
    remoteRef:
      key: moneyrabbit-mariadb-secret
      property: MARIADB_PASSWORD
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
   - 1Password項目`tailscale-operator-secret`を作成
   - `manifests/tailscale/`・`manifests/namespaces/tailscale.yaml`を作成
   - `master`にpush → ArgoCDで同期・IngressClass`tailscale`が作成されることを確認

2. **1Password項目作成**
   - `moneyrabbit-mariadb-secret`（MARIADB_ROOT_PASSWORD, MARIADB_PASSWORD）
   - `moneyrabbit-secret`（ANTHROPIC_API_KEY）

3. **Ansible変数追加→ディレクトリ作成**
   - `server_setup_k8s_pv_dirs`にMariaDB HDDパスを追記
   - `ansible-playbook playbooks/workers.yml`でディレクトリ作成

4. **マニフェスト作成・ローカル検証**
   - 上記のマニフェストを作成
   - `kustomize build --enable-helm ./manifests/moneyrabbit/`でレンダリングを確認
   - Kustomizeパッチが正しくSecretKeyRefに差し替えられているか検証

5. **pushとArgoCDデプロイ**
   - `master`にpush → ArgoCDが自動同期

6. **動作確認**
   - `kubectl get pods -n moneyrabbit`で全PodがReadyになるまで確認
   - Tailnetに接続した状態で`https://moneyrabbit.<tailnet>.ts.net`にアクセス
   - CSVインポート・カテゴリ分類・ダッシュボード表示を確認

## 11. 進捗

| フェーズ | ステータス |
|---------|----------|
| 設計書作成 | ✅ 完了 |
| Tailscale Operator導入 | ⏳ 未実施 |
| 1Password項目作成 | ⏳ 未実施 |
| Ansible PVディレクトリ追加 | ⏳ 未実施 |
| マニフェスト作成・ローカル検証 | ⏳ 未実施 |
| 本番デプロイ・動作確認 | ⏳ 未実施 |
