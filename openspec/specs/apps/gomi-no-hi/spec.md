## Purpose

越谷市のごみ収集日を確認し、前日夜・当日朝にプッシュ通知を送信する PWA アプリ「gomi-no-hi」を Kubernetes クラスタ上で稼働させ、Tailscale VPN 経由でアクセス可能にする。

## Requirements

### Requirement: アプリケーションが Tailscale VPN 経由でアクセス可能であること

gomi-no-hi frontend（React PWA）と backend（Go API）が Kubernetes クラスタ上で稼働し、
Tailscale Ingress 経由で `gomi-no-hi.<tailnet>.ts.net` という MagicDNS 名でアクセスできること。
インターネットには公開されない。

#### Scenario: Tailscale VPN 接続済み端末からフロントエンドにアクセスできる
- **WHEN** Tailscale VPN に接続済みの端末が `https://gomi-no-hi.<tailnet>.ts.net/` にアクセスする
- **THEN** gomi-no-hi PWA フロントエンドが応答を返す

#### Scenario: Tailscale VPN 接続済み端末から API にアクセスできる
- **WHEN** Tailscale VPN に接続済みの端末が `https://gomi-no-hi.<tailnet>.ts.net/api/` 以下のエンドポイントにアクセスする
- **THEN** gomi-no-hi バックエンド API が応答を返す

#### Scenario: VPN 未接続端末はアクセスできない
- **WHEN** Tailscale VPN に接続していない端末が gomi-no-hi にアクセスしようとする
- **THEN** 接続が拒否される（Tailscale MagicDNS で名前解決できない、またはルーティングされない）

### Requirement: プッシュ通知サブスクリプションが永続化されること

Redis にプッシュ通知サブスクリプション情報を保存し、Pod 再起動後も購読データが失われないこと。

#### Scenario: Pod 再起動後もサブスクリプションが保持される
- **WHEN** backend Pod または Redis Pod が再起動する
- **THEN** 再起動前に登録されたプッシュ通知サブスクリプションが引き続き有効である

### Requirement: プッシュ通知が定期的に送信されること

backend CronJob が毎時 0 分に実行され、登録済みサブスクリプションに対してごみ収集スケジュールに基づくプッシュ通知を送信すること。

#### Scenario: CronJob が毎時実行される
- **WHEN** 毎時 0 分になる
- **THEN** backend CronJob が起動し、対象ユーザーへのプッシュ通知を送信する

### Requirement: シークレットが ESO + 1Password で管理されること

VAPID キー（public/private/subject）と Redis パスワードは 1Password Vault から ESO 経由で Kubernetes Secret として同期されること。シークレットのプレーンテキストはリポジトリにコミットされない。

#### Scenario: ExternalSecret が Secret を作成する
- **WHEN** ExternalSecret リソースが存在し、1Password Connect が稼働している
- **THEN** `gomi-no-hi-backend-secret` および `gomi-no-hi-redis-secret` という名前の Kubernetes Secret が `gomi-no-hi` Namespace に作成される

### Requirement: ArgoCD による GitOps 管理がされること

`manifests/gomi-no-hi/` への変更が master ブランチにプッシュされると、ArgoCD が自動で同期（prune 有効）すること。

#### Scenario: マニフェスト変更が自動同期される
- **WHEN** `manifests/gomi-no-hi/` 配下のファイルが master ブランチに push される
- **THEN** ArgoCD が変更を検知して自動的にクラスタに適用する
