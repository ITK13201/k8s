## Context

クラスタには ESO + 1Password Connect・Tailscale Operator・ArgoCD（prune 有効）がすでにデプロイ済み。
gomi-no-hi / moneyrabbit が同パターン（Helm + Kustomize + Tailscale Ingress + ESO）で稼働しており、それを踏襲する。

CalendarRabbit の Helm チャートはアプリリポジトリの `charts/calendarrabbit/` に存在し、**OCI レジストリ `oci://ghcr.io/itk13201`** に公開されている（chart 名 `calendarrabbit`、version `0.1.0`）。これは gomi-no-hi と同じ OCI 参照方式であり、moneyrabbit の GitHub Pages 参照とは異なる。

チャート構成（`charts/calendarrabbit/`）:
- `backend`（Deployment + Service）: `ghcr.io/itk13201/calendarrabbit-backend`、port 8080、`/api/health` に readiness/liveness probe。env に `DB_HOST/PORT/USER/NAME`・`CLAUDE_MODEL`・`ALLOWED_ORIGINS`、Secret から `DB_PASSWORD`・`CLAUDE_API_KEY`
- `frontend`（Deployment + Service + ConfigMap）: `ghcr.io/itk13201/calendarrabbit-frontend`、nginx port 80、`BACKEND_URL` を ConfigMap で注入
- `mysql`（StatefulSet + Service）: `mariadb:11.4`、port 3306、volumeClaimTemplate `data`（`persistence.storageClass` 指定時のみ storageClassName を設定）
- `backend-secret`（Secret）: `backend.secret.existingSecret` 未指定時のみ生成。キーは `CLAUDE_API_KEY`・`DB_PASSWORD`
- `mysql-secret`（Secret）: `mysql.secret.existingSecret` 未指定時のみ生成。キーは `MYSQL_PASSWORD`・`MYSQL_ROOT_PASSWORD`
- ingress テンプレートはチャート 0.1.0 で削除済み（独自の Tailscale Ingress を使う）

## Goals / Non-Goals

**Goals:**
- CalendarRabbit（frontend + backend + MariaDB）を k8s クラスタ上で稼働させる
- Tailscale VPN 経由でのみアクセス可能にする
- ESO + 1Password でシークレットを管理する
- ArgoCD GitOps で自動同期する
- MariaDB データを永続化する

**Non-Goals:**
- インターネット公開（Cloudflare tunnel / ingress-nginx は使用しない）
- Renovate による自動バージョン更新（0.x チャートのため手動管理対象）

## Decisions

### Helm チャートの参照方式（OCI）

**決定**: kustomization.yaml の `helmCharts` で `repo: oci://ghcr.io/itk13201`・`name: calendarrabbit`・`version: 0.1.0` を指定して OCI レジストリを参照する。gomi-no-hi と同じ OCI パターン。

| 選択肢 | 概要 | 却下理由 |
|--------|------|---------|
| OCI レジストリ経由（採用） | `repo: oci://ghcr.io/itk13201` で OCI チャートを参照 | gomi-no-hi で実績あり・アプリ側で OCI 公開済み |
| GitHub Pages 経由 | `repo:` で公開 Helm repo を参照 | CalendarRabbit は OCI 公開のため不適 |

kustomize がビルド時に OCI チャートをダウンロード・キャッシュする（`--enable-helm` 必須）。OCI パッケージが public であれば追加認証は不要（gomi-no-hi で確認済みの前提）。

### fullnameOverride によるリソース名の固定

**決定**: values.yaml で `fullnameOverride: calendarrabbit` を設定する。

チャートの `fullname` ヘルパーは `{{ .Release.Name }}-{{ .Chart.Name }}` を生成するため、releaseName `calendarrabbit` のままでは `calendarrabbit-calendarrabbit-backend` のように冗長な名前になる。`fullnameOverride: calendarrabbit` を指定することで Service 名を `calendarrabbit-backend`・`calendarrabbit-frontend`・`calendarrabbit-mysql` に固定し、Ingress からの参照を安定させる。

### ストレージ配置

**決定**: MariaDB PV を HDD（`/mnt/hdd/data/k8s/pv/calendarrabbit/mysql`、5Gi）に配置する。

個人用アプリのためデータ量は少なく SSD を消費する必要はない。moneyrabbit の MariaDB も HDD に配置しており同方針。チャートの `mysql.persistence.storageClass` に `manual` を指定し、事前作成した PV にバインドする。volumeClaimTemplate にはセレクタが無いため、`manual` storageClass の Available な PV に自動バインドされる（他アプリの unbound manual PV と競合しないよう、PV 作成順・容量に留意）。

### シークレット構成

**決定**: 2 つの ExternalSecret で 1Password Vault から backend/mysql 用の Secret をそれぞれ同期し、`backend.secret.existingSecret`・`mysql.secret.existingSecret` で参照する。チャート 0.1.0 が Secret を backend/mysql に分割したため、gomi-no-hi/moneyrabbit と同じ 2 Secret 構成にする。

| K8s Secret 名 | 1Password アイテム名 | キー |
|--------------|---------------------|------|
| `calendarrabbit-backend-secret` | `calendarrabbit-backend-secret` | CLAUDE_API_KEY, DB_PASSWORD |
| `calendarrabbit-mysql-secret` | `calendarrabbit-mysql-secret` | MYSQL_PASSWORD, MYSQL_ROOT_PASSWORD |

backend は `calendarrabbit-backend-secret` から `CLAUDE_API_KEY`・`DB_PASSWORD` を、MariaDB StatefulSet は `calendarrabbit-mysql-secret` から `MYSQL_PASSWORD`・`MYSQL_ROOT_PASSWORD` を参照する。`DB_PASSWORD`（backend）と `MYSQL_PASSWORD`（mysql）は同じアプリ用 DB パスワードを設定する（backend が接続に使うため一致必須）。

### コンテナイメージ

`ghcr.io/itk13201/calendarrabbit-{frontend,backend}` を使用する。チャートの Deployment テンプレートには `imagePullSecrets` フィールドが無いが、両イメージは public GHCR パッケージであることを確認済み（匿名トークンで tags list を取得可能）。image tag は values.yaml で `0.0.1`（現行の最新 semver タグ）に固定する（チャート既定の `latest` は使わない）。`backend.env.allowedOrigins` は VPN 限定アクセスのためチャート既定の `*` のままとする。

### Ingress とルーティング

Tailscale Ingress（`ingressClassName: tailscale`）を独自に定義する。チャート 0.1.0 で ingress テンプレートは削除されたため、チャート側の設定は不要。ルーティング:
- `/api` → `calendarrabbit-backend:8080`
- `/swagger` → `calendarrabbit-backend:8080`
- `/` → `calendarrabbit-frontend:80`

TLS は Tailscale Operator が終端する（cert-manager 不要）。Ingress `name: calendarrabbit` が MagicDNS ホスト名になる。

## Risks / Trade-offs

- **OCI チャートの可用性**: OCI チャート `oci://ghcr.io/itk13201/calendarrabbit:0.1.0` および両コンテナイメージ `:0.0.1` が public であることを確認済み（認証不要）。gomi-no-hi でも OCI 参照が動作している実績あり。
- **同一バージョンでの再公開**: チャート 0.1.0 は Secret 分割・ingress 削除に伴い、同バージョンのまま内容を差し替えて再公開されている（digest が変化）。kustomize/helm がローカルにキャッシュした旧 0.1.0 を使うと反映されないため、再レンダリング前にチャートキャッシュをクリアする（helm のリポジトリキャッシュ削除、または `manifests/calendarrabbit/charts/` にバンドルされた旧チャートがあれば削除）。
- **チャートバージョン管理**: kustomization.yaml の `version:` は手動更新。Renovate は 0.x のため対象外。
- **manual PV バインドの非決定性**: volumeClaimTemplate にセレクタが無いため、複数の unbound manual PV があると意図しない PV にバインドされうる。PV は他アプリと容量・作成タイミングで区別する。
- **VPN 限定アクセス**: 新しいデバイスで Tailscale を設定するまでサービスにアクセスできない。

## Migration Plan

1. 1Password Vault に `calendarrabbit-backend-secret`（CLAUDE_API_KEY・DB_PASSWORD）・`calendarrabbit-mysql-secret`（MYSQL_PASSWORD・MYSQL_ROOT_PASSWORD）の 2 アイテムを登録（DB_PASSWORD と MYSQL_PASSWORD は同値）
2. Ansible で MariaDB PV ディレクトリを作成（`/mnt/hdd/data/k8s/pv/calendarrabbit/mysql`）
3. マニフェスト作成・`kustomize build --enable-helm ./manifests/calendarrabbit/` でレンダリング確認
4. master push → ArgoCD 自動同期
5. 動作確認（Pod Ready、Tailscale 経由アクセス、予定登録）

**ロールバック**: ArgoCD で前リビジョンに戻すか、`manifests/calendarrabbit/` を削除して prune で全削除。MariaDB PV は `reclaimPolicy: Retain` のため手動削除が必要。
