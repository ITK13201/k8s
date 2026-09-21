# CalendarRabbit デプロイ設計書

## 1. 概要

CalendarRabbit はチャット駆動で予定を登録できる個人用 PWA アプリ。
LLM（既定は DeepSeek、Claude へ切り戻し可能）を利用して自然言語から予定を抽出し、MariaDB に永続化する。DeepSeek 経路では web 検索（Tavily）による事前検索で外部情報を補完する。また Google Calendar 連携（OAuth 2.0）により抽出した予定を Google Calendar に登録できる。
Helm チャートを **OCI レジストリ `oci://ghcr.io/itk13201`**（chart 名 `calendarrabbit`、version `1.0.2`）から参照してデプロイする（gomi-no-hi と同じ OCI 参照方式であり、moneyrabbit の GitHub Pages 参照とは異なる）。chart の `appVersion` は `1.0.0` であり、frontend/backend のアプリイメージ tag は `1.0.0` を使用する（chart version `1.0.2` とイメージ tag は一致しない点に注意）。
Tailscale Operator が提供する IngressClass を使い、Tailnet のみからアクセス可能にする（公開しない）。

## 2. コンポーネント構成

| コンポーネント | 技術 | イメージ | ポート |
|--------------|------|---------|--------|
| frontend | PWA + Nginx | `ghcr.io/itk13201/calendarrabbit-frontend:1.0.0` | 80 |
| backend | API（`/api/health` に probe） | `ghcr.io/itk13201/calendarrabbit-backend:1.0.0` | 8080 |
| mysql | MariaDB 11.4（StatefulSet） | `mariadb:11.4` | 3306（クラスタ内部のみ） |

- backend は env に `DB_HOST/PORT/USER/NAME`・`LLM_PROVIDER`・`CLAUDE_MODEL`・`DEEPSEEK_MODEL`・`DEEPSEEK_BASE_URL`・`SEARCH_PROVIDER`・`SEARCH_MAX_RESULTS`・`ALLOWED_ORIGINS` を持ち、Secret から `DB_PASSWORD`・`CLAUDE_API_KEY`・`DEEPSEEK_API_KEY`・`SEARCH_API_KEY`・`GOOGLE_OAUTH_CLIENT_ID`・`GOOGLE_OAUTH_CLIENT_SECRET`・`GOOGLE_OAUTH_REDIRECT_URL`・`GOOGLE_TOKEN_ENC_KEY` を参照する（8 キーは `optional` 指定なしのため欠落すると起動失敗）。
- frontend は `BACKEND_URL` を ConfigMap で注入し、nginx が backend Service へプロキシする。
- mysql は StatefulSet + volumeClaimTemplate（`data`）で永続化し、Secret から `MYSQL_PASSWORD`・`MYSQL_ROOT_PASSWORD` を参照する。

両コンテナイメージは public GHCR パッケージ（`imagePullSecrets` 不要）。image tag は `0.2.0` に固定する（チャート既定の `latest` は使わない）。

## 3. アーキテクチャ

```
Tailnet クライアント（VPN 接続済み端末）
    ↓ HTTPS (MagicDNS: calendarrabbit.<tailnet>.ts.net)
Tailscale Operator（IngressClass: tailscale）
    ├── /api/*      → calendarrabbit-backend:8080
    ├── /swagger/*  → calendarrabbit-backend:8080
    └── /           → calendarrabbit-frontend:80
                            ↓
                       backend Pod
                            ↓ TCP 3306
                       mysql StatefulSet
                       (PV: /mnt/hdd/data/k8s/pv/calendarrabbit/mysql)
```

Tailscale Ingress は Tailnet の MagicDNS で名前解決される。公開インターネットには露出しない。
backend は予定抽出のため外部の LLM API（既定 DeepSeek、切り戻し時 Claude）を呼び出し、DeepSeek 経路では Tavily 検索 API へのアウトバウンド通信も発生する。

## 4. ストレージ設計

| リソース | 容量 | ホストパス | storageClass | reclaimPolicy |
|---------|------|-----------|-------------|---------------|
| MariaDB PV | 5Gi | `/mnt/hdd/data/k8s/pv/calendarrabbit/mysql` | manual | Retain |

個人用アプリのためデータ量は少なく SSD を消費する必要はない。moneyrabbit の MariaDB と同じ HDD 配置方針。
チャートの `mysql.persistence.storageClass` に `manual` を指定し、事前作成した PV にバインドする。volumeClaimTemplate にはセレクタが無いため、`manual` storageClass の Available な PV に自動バインドされる（他アプリの unbound manual PV と競合しないよう PV 作成順・容量に留意）。

## 5. シークレット設計

ESO + 1Password Connect で管理する。チャートは Secret を backend 用・mysql 用に分割しているため、2 つの ExternalSecret を定義する。

| K8s Secret 名 | 1Password アイテム名 | キー |
|--------------|---------------------|------|
| `calendarrabbit-secret` | `calendarrabbit-secret` | CLAUDE_API_KEY, DB_PASSWORD, DEEPSEEK_API_KEY, SEARCH_API_KEY, GOOGLE_OAUTH_CLIENT_ID, GOOGLE_OAUTH_CLIENT_SECRET, GOOGLE_OAUTH_REDIRECT_URL, GOOGLE_TOKEN_ENC_KEY |
| `calendarrabbit-mysql-secret` | `calendarrabbit-mysql-secret` | MYSQL_PASSWORD, MYSQL_ROOT_PASSWORD |

backend は `calendarrabbit-secret` から `DB_PASSWORD`・`CLAUDE_API_KEY`・`DEEPSEEK_API_KEY`・`SEARCH_API_KEY`・`GOOGLE_OAUTH_CLIENT_ID`・`GOOGLE_OAUTH_CLIENT_SECRET`・`GOOGLE_OAUTH_REDIRECT_URL`・`GOOGLE_TOKEN_ENC_KEY` を、MariaDB StatefulSet は `calendarrabbit-mysql-secret` から `MYSQL_PASSWORD`・`MYSQL_ROOT_PASSWORD` を参照する。
`DB_PASSWORD` と `MYSQL_PASSWORD` は同じアプリ用 DB パスワードを設定する（backend が接続に使うため一致必須。別アイテムに同値で登録する）。
1.0.0 の backend Deployment は上記 8 キーを `optional` 指定なしの `secretKeyRef` で参照するため、いずれかが欠落すると backend Pod は `CreateContainerConfigError` で起動しない。各 API キーの実値は 1Password へ半手動で登録する。`GOOGLE_TOKEN_ENC_KEY` は OAuth トークン暗号化鍵（32 バイト乱数）。

values.yaml で `backend.secret.existingSecret: calendarrabbit-secret`・`mysql.secret.existingSecret: calendarrabbit-mysql-secret` を指定することで、チャートは自前の Secret を生成せず、各 ExternalSecret が同期した Secret を参照する。

## 6. マニフェスト構成

```
manifests/
├── namespaces/
│   └── calendarrabbit.yaml          # Namespace 追加
├── pv/
│   └── calendarrabbit-mysql.yaml    # MariaDB PV（5Gi、HDD）
└── calendarrabbit/
    ├── kustomization.yaml            # helmCharts（OCI）+ resources
    ├── values.yaml                   # Helm values
    ├── external-secret.yaml          # backend / mysql の 2 つの ExternalSecret
    └── ingress-tailscale.yaml        # Tailscale Ingress
```

### kustomization.yaml

```yaml
namespace: calendarrabbit
resources:
- external-secret.yaml
- ingress-tailscale.yaml
helmCharts:
- name: calendarrabbit
  repo: oci://ghcr.io/itk13201
  version: 1.0.2
  releaseName: calendarrabbit
  namespace: calendarrabbit
  valuesFile: values.yaml
  valuesMerge: override
```

kustomize がビルド時に OCI チャートをダウンロード・キャッシュする（`--enable-helm` 必須）。OCI パッケージが public であれば追加認証は不要（gomi-no-hi で実績あり）。

### values.yaml

```yaml
fullnameOverride: calendarrabbit
frontend:
  image:
    repository: ghcr.io/itk13201/calendarrabbit-frontend
    tag: "1.0.0"
backend:
  image:
    repository: ghcr.io/itk13201/calendarrabbit-backend
    tag: "1.0.0"
  env:
    llmProvider: deepseek
    allowedOrigins: "*"
  secret:
    existingSecret: calendarrabbit-secret
mysql:
  image:
    repository: mariadb
    tag: "11.4"
  secret:
    existingSecret: calendarrabbit-mysql-secret
  persistence:
    storageClass: manual
    size: 5Gi
```

`fullnameOverride: calendarrabbit` により Service 名を `calendarrabbit-backend`・`calendarrabbit-frontend`・`calendarrabbit-mysql` に固定する（未指定だとチャートの fullname ヘルパーが `calendarrabbit-calendarrabbit-backend` のような冗長名を生成し Ingress 参照が不安定になる）。
`backend.env.allowedOrigins` は VPN 限定アクセスのためチャート既定の `*` のままとする。
`backend.env.llmProvider: deepseek` で本番の LLM プロバイダを DeepSeek に固定する。`deepseekModel`（`deepseek-v4-pro`）・`deepseekBaseURL`（`https://api.deepseek.com`）・`searchProvider`（`tavily`）・`searchMaxResults`（`10`）はチャート既定に委ね values には書かない。Claude へ切り戻す場合は `llmProvider: claude` の 1 行変更で対応する。

## 7. Tailscale Ingress 設計

```yaml
ingressClassName: tailscale
rules:
- http:
    paths:
    - path: /api      → calendarrabbit-backend:8080
    - path: /swagger  → calendarrabbit-backend:8080
    - path: /         → calendarrabbit-frontend:80
tls:
- hosts:
  - calendarrabbit
```

TLS は Tailscale Operator が自動で終端する（cert-manager 不要）。
チャートの ingress は `ingress.enabled: false`（既定）のまま無効化し、独自の Tailscale Ingress を使う。
MagicDNS 名は `calendarrabbit.<tailnet>.ts.net`。

## 8. Ansible PV ディレクトリ追加

`ansible/inventory/group_vars/workers/main.yml` の `server_setup_k8s_pv_dirs` HDD セクションに追加:

```yaml
- /mnt/hdd/data/k8s/pv/calendarrabbit/mysql
```

適用:

```bash
cd ansible/
ansible-playbook playbooks/workers.yml --tags setup
```

## 9. ArgoCD 管理

`manifests/argocd/application-set.yaml` の ApplicationSet が `manifests/*` を自動検出するため、追記は不要。`master` push 後に ArgoCD が `k8s-calendarrabbit` アプリを自動生成する。

## 10. バージョン管理

Helm チャートと frontend/backend イメージは Renovate 対象外のため手動管理。チャート更新時は kustomization.yaml の `version:` と values.yaml の image tag を手動更新する。なお chart version（`1.0.2`）と appVersion（`1.0.0`）は一致しないため、image tag は chart version ではなく appVersion（`1.0.0`）を使用すること。

データベースイメージは values.yaml で `mysql.image.repository: mariadb`・`mysql.image.tag: "11.4"` を明示指定してタグ管理する（チャートの values キーは `mysql` のままだが、チャート 0.1.2 で既定イメージが MariaDB に変更された）。`mariadb:11.4` は non-0.x のため Renovate が YAML 内 Docker イメージタグとして追跡し、minor/patch を自動マージする。major アップグレードは手動レビュー。

## 11. 実装手順

### 初回デプロイ手順

1. **1Password Vault にシークレット登録**
   - `calendarrabbit-secret`（CLAUDE_API_KEY・DB_PASSWORD・DEEPSEEK_API_KEY・SEARCH_API_KEY・GOOGLE_OAUTH_CLIENT_ID・GOOGLE_OAUTH_CLIENT_SECRET・GOOGLE_OAUTH_REDIRECT_URL・GOOGLE_TOKEN_ENC_KEY）
   - `calendarrabbit-mysql-secret`（MYSQL_PASSWORD・MYSQL_ROOT_PASSWORD）
   - `DB_PASSWORD` と `MYSQL_PASSWORD` は同値にする
   - `GOOGLE_TOKEN_ENC_KEY` は 32 バイト乱数（Base64 等でエンコード）
   - `GOOGLE_OAUTH_REDIRECT_URL` は `https://calendarrabbit.<tailnet>.ts.net/<callback-path>` 形式

2. **Ansible で MariaDB PV ディレクトリ作成**
   - `server_setup_k8s_pv_dirs` に `/mnt/hdd/data/k8s/pv/calendarrabbit/mysql` を追加
   - `ansible-playbook playbooks/workers.yml --tags setup` を実行

3. **マニフェスト作成・レンダリング確認**
   - `kustomize build --enable-helm ./manifests/calendarrabbit/` で frontend/backend の Deployment/Service、MariaDB の StatefulSet/Service、Ingress、ExternalSecret が出力されることを確認

4. **master push → ArgoCD 自動同期**

5. **動作確認**
   - `kubectl get pods -n calendarrabbit` で全 Pod（frontend・backend・mysql）が Running/Ready になることを確認
   - `kubectl get secret calendarrabbit-secret -n calendarrabbit -o jsonpath='{.data}'` に 8 キーが揃っていることを確認
   - `kubectl get pvc -n calendarrabbit` が `calendarrabbit-mysql-pv` に Bound していることを確認
   - Tailscale VPN 接続済みの端末で `https://calendarrabbit.<tailnet>.ts.net/` にアクセスし、PWA フロントエンド・`/api/health`・`/swagger` が応答することを確認
   - Google Calendar 連携の OAuth フローを実行し、抽出した予定が Google Calendar に登録できることを確認

### バージョンアップグレード手順（v1.0.2）

1. **Google Cloud で OAuth 2.0 クライアントを作成**し、`/swagger` またはアプリ仕様でコールバックパスを確認してリダイレクト URI を登録
2. **シークレット先行**: `external-secret.yaml` に `GOOGLE_OAUTH_CLIENT_ID`・`GOOGLE_OAUTH_CLIENT_SECRET`・`GOOGLE_OAUTH_REDIRECT_URL`・`GOOGLE_TOKEN_ENC_KEY` を追加して push → ESO が同期するまで待機
3. `kubectl get secret calendarrabbit-secret -n calendarrabbit` で 8 キーを確認後、`kustomization.yaml`（chart `1.0.2`）・`values.yaml`（image tag `1.0.0`）を更新して push
4. ArgoCD 同期後に backend/frontend Pod が Running になることを確認

**ロールバック**: `kustomization.yaml` の version を戻し、`values.yaml` の image tag を戻して push。Secret に追加したキーは残しても無害。
