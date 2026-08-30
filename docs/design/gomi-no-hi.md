# gomi-no-hi デプロイ設計書

## 1. 概要

[gomi-no-hi](https://github.com/ITK13201/gomi-no-hi) は越谷市のごみ収集日を確認し、前日夜・当日朝にプッシュ通知を送信する個人用 PWA アプリ。
公式 Helm chart（`https://itk13201.github.io/gomi-no-hi`）を使用してデプロイする。
Tailscale Operator が提供する IngressClass を使い、Tailnet のみからアクセス可能にする（公開しない）。

## 2. コンポーネント構成

| コンポーネント | 技術 | イメージ | ポート |
|--------------|------|---------|--------|
| frontend | React + Nginx | `ghcr.io/itk13201/gomi-no-hi-frontend` | 80 |
| backend | Go + Gin | `ghcr.io/itk13201/gomi-no-hi-backend` | 8080 |
| redis | Redis 7-alpine | `redis:7-alpine` | 6379（クラスタ内部のみ） |
| backend-notify | CronJob（毎時 0 分） | `ghcr.io/itk13201/gomi-no-hi-backend` | — |

コンテナイメージは gomi-no-hi リポジトリの GitHub Actions でビルド・GHCR に push される（Private リポジトリ）。

## 3. アーキテクチャ

```
Tailnet クライアント（VPN 接続済み端末）
    ↓ HTTPS (MagicDNS: gomi-no-hi.<tailnet>.ts.net)
Tailscale Operator（IngressClass: tailscale）
    ├── /api/*  → gomi-no-hi-backend-svc:8080
    └── /       → gomi-no-hi-frontend-svc:80
                         ↓
                    backend Pod
                         ↓ TCP 6379
                    redis Deployment
                    (PV: /mnt/hdd/data/k8s/pv/gomi-no-hi/redis)

gomi-no-hi-backend-notify CronJob（毎時 0 分）
    → 登録済みサブスクリプションへプッシュ通知送信
    → Redis からサブスクリプション取得 → Web Push API
```

Tailscale Ingress は Tailnet の MagicDNS で名前解決される。公開インターネットには露出しない。
プッシュ通知は backend CronJob がクラスタ内から外部の Web Push エンドポイント（Google FCM / Mozilla Push 等）に送信するため、ユーザーがオフライン中でも通知を受け取れる。

## 4. ストレージ設計

| リソース | 容量 | ホストパス | storageClass | reclaimPolicy |
|---------|------|-----------|-------------|---------------|
| Redis PV | 1Gi | `/mnt/hdd/data/k8s/pv/gomi-no-hi/redis` | manual | Retain |

個人用アプリのため Push 通知サブスクリプション数が少なく、SSD を消費する必要はない。Nextcloud の Redis（`/mnt/hdd/data/k8s/pv/nextcloud/redis-master`）と同じ HDD 配置方針。

## 5. シークレット設計

ESO + 1Password Connect で管理する。

| K8s Secret 名 | 1Password アイテム名 | キー |
|--------------|---------------------|------|
| `gomi-no-hi-backend-secret` | `gomi-no-hi-backend-secret` | VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT, REDIS_PASSWORD |
| `gomi-no-hi-redis-secret` | `gomi-no-hi-redis-secret` | REDIS_PASSWORD |

backend Deployment と backend-notify CronJob は両方 `gomi-no-hi-backend-secret` から REDIS_PASSWORD と VAPID キーを参照する。Redis Pod は `gomi-no-hi-redis-secret` から REDIS_PASSWORD を参照する。

VAPID キーは `npx web-push generate-vapid-keys` で生成し、1Password Vault に手動登録する。

### ghcr-secret

`ghcr.io/itk13201/gomi-no-hi-{frontend,backend}` は GHCR の private image のため、`ghcr-secret`（`kubernetes.io/dockerconfigjson` 型）を `gomi-no-hi` Namespace に手動で作成する必要がある（ESO 管理外）。

```bash
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<GitHubユーザー名> \
  --docker-password=<PAT(read:packages)> \
  -n gomi-no-hi
```

## 6. マニフェスト構成

```
manifests/
├── namespaces/
│   └── gomi-no-hi.yaml              # Namespace 追加
├── pv/
│   └── gomi-no-hi-redis.yaml        # Redis PV（1Gi、HDD）
└── gomi-no-hi/
    ├── kustomization.yaml            # helmCharts + resources
    ├── values.yaml                   # Helm values
    ├── external-secret.yaml          # backend-secret + redis-secret の ExternalSecret
    ├── ingress-tailscale.yaml        # Tailscale Ingress
    └── charts/
        └── gomi-no-hi-0.1.0/        # バンドル済み Helm チャート（private repo のため）
            └── gomi-no-hi/
```

### kustomization.yaml

```yaml
namespace: gomi-no-hi
helmCharts:
- name: gomi-no-hi
  repo: https://itk13201.github.io/gomi-no-hi
  version: 0.1.0
  releaseName: gomi-no-hi
  namespace: gomi-no-hi
  valuesFile: values.yaml
```

チャートは Private GitHub リポジトリからリリースされるため、`charts/gomi-no-hi-0.1.0/` にローカルバンドルしている。チャート更新時は `gh release download` で再ダウンロードして差し替える。

### values.yaml

```yaml
frontend:
  image:
    repository: ghcr.io/itk13201/gomi-no-hi-frontend
    tag: "2.0.0"
backend:
  image:
    repository: ghcr.io/itk13201/gomi-no-hi-backend
    tag: "2.0.0"
  existingSecret: gomi-no-hi-backend-secret
redis:
  host: gomi-no-hi-redis   # チャートデフォルト "redis" を上書き
  auth:
    existingSecret: gomi-no-hi-redis-secret
  persistence:
    storageClass: manual
    size: 1Gi
```

`redis.host` はチャートの Service 名（`gomi-no-hi-redis`）に合わせて上書きが必要。

## 7. Tailscale Ingress 設計

```yaml
ingressClassName: tailscale
rules:
- http:
    paths:
    - path: /api    → gomi-no-hi-backend:8080
    - path: /       → gomi-no-hi-frontend:80
tls:
- hosts:
  - gomi-no-hi
```

TLS は Tailscale Operator が自動で終端する（cert-manager 不要）。
MagicDNS 名は `gomi-no-hi.<tailnet>.ts.net`。

## 8. Ansible PV ディレクトリ追加

`ansible/inventory/group_vars/workers/main.yml` の `server_setup_k8s_pv_dirs` HDD セクションに追加:

```yaml
- /mnt/hdd/data/k8s/pv/gomi-no-hi/redis
```

適用:

```bash
cd ansible/
ansible-playbook playbooks/workers.yml --tags setup
```

## 9. ArgoCD 管理

`manifests/argocd/application-set.yaml` の ApplicationSet が `manifests/*` を自動検出するため、追記は不要。`master` push 後に ArgoCD が `k8s-gomi-no-hi` アプリを自動生成する。

## 10. チャート更新手順

gomi-no-hi リポジトリは Private のため、チャート更新時は以下の手順:

```bash
# 新バージョンのチャートをダウンロード
gh release download gomi-no-hi-<version> --repo ITK13201/gomi-no-hi --dir /tmp/gomi-no-hi/

# charts/ に展開
mkdir -p manifests/gomi-no-hi/charts/gomi-no-hi-<version>
tar xzf /tmp/gomi-no-hi/gomi-no-hi-<version>.tgz -C manifests/gomi-no-hi/charts/gomi-no-hi-<version>/

# kustomization.yaml の version を更新
# values.yaml の image tag を更新
```

## 11. 実装手順

1. **1Password Vault にシークレット登録**
   - `gomi-no-hi-backend-secret`（VAPID_PUBLIC_KEY/PRIVATE_KEY/SUBJECT + REDIS_PASSWORD）
   - `gomi-no-hi-redis-secret`（REDIS_PASSWORD）
   - VAPID キーは `npx web-push generate-vapid-keys` で生成

2. **Ansible で Redis PV ディレクトリ作成**
   - `server_setup_k8s_pv_dirs` に `/mnt/hdd/data/k8s/pv/gomi-no-hi/redis` を追加
   - `ansible-playbook playbooks/workers.yml --tags setup` を実行

3. **master push → ArgoCD 自動同期**

4. **ghcr-secret を手動作成**（Namespace 作成後）
   - `kubectl create secret docker-registry ghcr-secret ...`

5. **動作確認**
   - `kubectl get pods -n gomi-no-hi` で全 Pod が Running/Ready になることを確認
   - Tailscale VPN 接続済みの端末で `https://gomi-no-hi.<tailnet>.ts.net/` にアクセス
   - ブラウザでプッシュ通知を許可しサブスクリプションを登録

**ロールバック**: ArgoCD で前リビジョンに戻すか、`manifests/gomi-no-hi/` を削除して prune で全削除。Redis PV は `reclaimPolicy: Retain` のため手動削除が必要。
