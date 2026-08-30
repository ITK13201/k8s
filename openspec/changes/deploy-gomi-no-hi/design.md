## Context

クラスタには ESO + 1Password Connect・Tailscale Operator・ArgoCD（prune 有効）がすでにデプロイ済み。
moneyrabbit が同パターン（Helm + Kustomize + Tailscale Ingress + ESO）で稼働しており、それを踏襲する。

gomi-no-hi の Helm チャートは `helm/gomi-no-hi/` に存在し、`helm-release.yml`（chart-releaser-action）によって GitHub Pages（`https://itk13201.github.io/gomi-no-hi/`）に公開されている。

## Goals / Non-Goals

**Goals:**
- gomi-no-hi（frontend + backend + Redis）を k8s クラスタ上で稼働させる
- Tailscale VPN 経由でのみアクセス可能にする
- ESO + 1Password でシークレットを管理する
- ArgoCD GitOps で自動同期する
- Redis データ（プッシュ通知サブスクリプション）を永続化する

**Non-Goals:**
- インターネット公開（Cloudflare tunnel / ingress-nginx は使用しない）
- Renovate による自動バージョン更新（0.x チャートのため手動管理対象）

## Decisions

### Helm チャートの参照方式

**決定**: kustomization.yaml の `helmCharts` で `repo: https://itk13201.github.io/gomi-no-hi` を指定して公開済み Helm リポジトリを参照する。moneyrabbit と同じパターン。

| 選択肢 | 概要 | 却下理由 |
|--------|------|---------|
| GitHub Pages 経由（採用） | `repo:` で公開 Helm repo を参照 | チャート更新が自動（chart-releaser-action） |
| ローカルバンドル | リポジトリ内にチャートをコピー | chart-releaser 導入済みのため不要 |

kustomize がビルド時にチャートをダウンロード・キャッシュする（`--enable-helm` 必須）。

### ストレージ配置

**決定**: Redis PV を HDD（`/mnt/hdd/data/k8s/pv/gomi-no-hi/redis`、1Gi）に配置する。

個人用アプリのため Push 通知サブスクリプション数が少なく、SSD を消費する必要はない。Nextcloud の Redis も HDD（`/mnt/hdd/data/k8s/pv/nextcloud/redis-master`）に配置しており、同じ方針を踏襲する。

### シークレット構成

**決定**: 2つの ExternalSecret で 1Password Vault から同期する。

| K8s Secret 名 | 1Password アイテム名 | キー |
|--------------|---------------------|------|
| `gomi-no-hi-backend-secret` | `gomi-no-hi-backend-secret` | VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT, REDIS_PASSWORD |
| `gomi-no-hi-redis-secret` | `gomi-no-hi-redis-secret` | REDIS_PASSWORD |

backend-cronjob も `existingSecret` から REDIS_PASSWORD と VAPID キーを読むため、redis secret と backend secret は独立して管理する。

### ghcr-secret

`ghcr.io/itk13201/gomi-no-hi-{frontend,backend}` は GHCR の private image のため、`ghcr-secret`（`kubernetes.io/dockerconfigjson` 型）を `gomi-no-hi` Namespace に手動で作成する必要がある。ESO での管理は現時点では不要（手動作成で十分）。

### Ingress とプッシュ通知の整合性

Tailscale Ingress を使う場合、VPN 外からフロントエンドにアクセスできない。ただしプッシュ通知は backend CronJob がクラスタ内から外部の Web Push エンドポイント（Google FCM / Mozilla Push 等）に送信する設計のため、ユーザーがオフライン中でも通知を受け取れる。初回サブスクリプション登録は VPN 接続時にのみ行えるが、登録後は VPN 接続不要。

## Risks / Trade-offs

- **チャートバージョン管理**: chart-releaser-action で公開されるが、kustomization.yaml の `version:` フィールドは手動で更新する必要がある。Renovate は 0.x のため対象外。チャート更新時は手動でバージョンを確認・更新すること。
- **ghcr-secret の手動管理**: ESO 管理外のため Namespace 再作成時に手動適用が必要。
- **VPN 限定アクセス**: 新しいデバイスで Tailscale を設定するまでサービスにアクセスできない。

## Migration Plan

1. 1Password Vault にシークレットアイテムを登録（`gomi-no-hi-backend-secret`・`gomi-no-hi-redis-secret`）
2. Ansible で Redis PV ディレクトリを作成（`/data/k8s/pv/gomi-no-hi/redis`）
3. マニフェスト作成・`kustomize build --enable-helm ./manifests/gomi-no-hi/` でレンダリング確認
4. `ghcr-secret` を `gomi-no-hi` Namespace に手動 apply（`kubectl apply -f secrets/gomi-no-hi/`）
5. master push → ArgoCD 自動同期
6. 動作確認（Pod Ready、Tailscale 経由アクセス、プッシュ通知登録）

**ロールバック**: ArgoCD で前リビジョンに戻すか、`manifests/gomi-no-hi/` を削除して prune で全削除。Redis PV は `reclaimPolicy: Retain` のため手動削除が必要。
