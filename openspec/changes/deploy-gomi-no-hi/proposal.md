## Why

個人用ごみ収集日通知 PWA アプリ「gomi-no-hi」を Kubernetes クラスタにデプロイし、Tailscale 経由でアクセス可能にする。
既存の MoneyRabbit デプロイと同様の構成（Helm + Kustomize + ArgoCD + Tailscale Ingress）を採用する。

## What Changes

- `manifests/namespaces/gomi-no-hi.yaml` — Namespace 追加
- `manifests/pv/gomi-no-hi-redis.yaml` — Redis 用 PersistentVolume 追加（HDD、1Gi）
- `manifests/pv/kustomization.yaml` — 上記 PV を追加
- `manifests/gomi-no-hi/` — values.yaml・外部Secret・Tailscale Ingress を新規作成（Helm チャートは GitHub Pages から参照）
- `ansible/inventory/group_vars/workers/main.yml` — Redis PV ホストパスディレクトリを追加
- `docs/design/gomi-no-hi.md` — デプロイ設計書を新規作成

## Capabilities

### New Capabilities

- `apps/gomi-no-hi`: gomi-no-hi PWA アプリ（frontend + backend + Redis）の Kubernetes デプロイメント。
  Tailscale Ingress による VPN 限定アクセス、ESO + 1Password によるシークレット管理（VAPID キー・Redis パスワード）、Redis PVC によるプッシュ通知サブスクリプション永続化を含む。

### Modified Capabilities

（なし）

## Impact

- **新規 Namespace**: `gomi-no-hi`
- **新規 PersistentVolume**: Redis 用 1Gi（HDD: `/mnt/hdd/data/k8s/pv/gomi-no-hi/redis`）
- **GHCR イメージ**: `ghcr.io/itk13201/gomi-no-hi-frontend`・`ghcr.io/itk13201/gomi-no-hi-backend`（既存の `ghcr-secret` を使用）
- **Helm チャート**: `https://itk13201.github.io/gomi-no-hi/` の公開 Helm リポジトリを参照（chart-releaser-action で自動公開）
- **1Password シークレット**: `gomi-no-hi-backend-secret`（VAPID_PUBLIC_KEY/PRIVATE_KEY/SUBJECT + REDIS_PASSWORD）・`gomi-no-hi-redis-secret`（REDIS_PASSWORD）
- **CronJob**: バックエンドが毎時 0 分にプッシュ通知を送信
- **Tailscale Ingress**: `gomi-no-hi.<tailnet>.ts.net` でアクセス（moneyrabbit と同様の構成）
- **Ansible**: workers の `server_setup_k8s_pv_dirs` に Redis ホストパスを追加
