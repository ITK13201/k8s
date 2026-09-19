## Why

チャット駆動で予定を登録できる個人用 PWA アプリ「CalendarRabbit」を Kubernetes クラスタにデプロイし、Tailscale 経由でアクセス可能にする。
既存の gomi-no-hi / MoneyRabbit デプロイと同様の構成（Helm + Kustomize + ArgoCD + Tailscale Ingress）を採用する。MoneyRabbit との唯一の差異は、Helm チャートを **OCI レジストリ（`oci://ghcr.io/itk13201`）** から参照する点で、これは gomi-no-hi と同じ方式である。

## What Changes

- `manifests/namespaces/calendarrabbit.yaml` — Namespace 追加
- `manifests/namespaces/kustomization.yaml` — 上記 Namespace を追加
- `manifests/pv/calendarrabbit-mysql.yaml` — MariaDB 用 PersistentVolume 追加（HDD、5Gi）
- `manifests/pv/kustomization.yaml` — 上記 PV を追加
- `manifests/calendarrabbit/` — kustomization.yaml（OCI Helm 参照）・values.yaml・external-secret.yaml（backend/mysql の 2 ExternalSecret）・ingress-tailscale.yaml を新規作成
- `ansible/inventory/group_vars/workers/main.yml` — MariaDB PV ホストパスディレクトリを追加
- `docs/design/calendarrabbit.md` — デプロイ設計書を新規作成、`CLAUDE.md` の設計書リストに追記

## Capabilities

### New Capabilities

- `apps/calendarrabbit`: CalendarRabbit PWA アプリ（frontend + backend + MariaDB）の Kubernetes デプロイメント。
  Tailscale Ingress による VPN 限定アクセス、ESO + 1Password によるシークレット管理（Claude API キー・DB パスワード）、MariaDB PVC によるデータ永続化を含む。Helm チャートは OCI レジストリから参照する。

### Modified Capabilities

（なし）

## Impact

- **新規 Namespace**: `calendarrabbit`
- **新規 PersistentVolume**: MariaDB 用 5Gi（HDD: `/mnt/hdd/data/k8s/pv/calendarrabbit/mysql`）
- **GHCR イメージ**: `ghcr.io/itk13201/calendarrabbit-frontend`・`ghcr.io/itk13201/calendarrabbit-backend`・`mariadb:11.4`
- **Helm チャート**: `oci://ghcr.io/itk13201`（chart 名 `calendarrabbit`、version `0.1.0`）を OCI レジストリから参照（gomi-no-hi と同方式、MoneyRabbit の GitHub Pages 参照とは異なる）
- **1Password シークレット**: `calendarrabbit-backend-secret`（CLAUDE_API_KEY・DB_PASSWORD）・`calendarrabbit-mysql-secret`（MYSQL_PASSWORD・MYSQL_ROOT_PASSWORD）。チャート 0.1.0 が Secret を backend/mysql に分割したため 2 アイテム構成。DB_PASSWORD と MYSQL_PASSWORD は同値
- **Tailscale Ingress**: `calendarrabbit.<tailnet>.ts.net` でアクセス（`/api`・`/swagger` → backend、`/` → frontend）
- **Ansible**: workers の `server_setup_k8s_pv_dirs` に MariaDB ホストパスを追加
