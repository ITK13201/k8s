## Why

docker-mailserver を廃止した際に Cloudflare の mail DNS レコード（MX/SPF/DMARC）をすべて削除した。  
今後は `i-tk.dev` ドメインのメールアドレスをさくらのレンタルサーバで受送信するため、Sakura 向けの DNS レコードを Terraform で再整備する。

## What Changes

- `terraform/cloudflare/dns_mail.tf` を新規作成し、以下の DNS レコードを追加する
  - MX レコード: `i-tk.dev` → さくらのメールサーバ
  - SPF TXT レコード: さくら送信元許可 (`v=spf1 include:spf.sakura.ne.jp ~all`)
  - DMARC TXT レコード: `_dmarc.i-tk.dev`（ポリシー: `quarantine` 推奨）
  - DKIM CNAME レコード（さくらが提供する場合）
- さくらのメールサーバホスト名は `var.sakura_mail_server` 変数として `variables.tf` に追加する
- `terraform/cloudflare/terraform.tfvars` に変数値を追記する
- Cloudflare プロキシ（オレンジ雲）は **無効**（メールは Cloudflare Proxy を通せないため）

## Capabilities

### New Capabilities

- `cloudflare/mail-dns`: i-tk.dev ドメインの Sakura レンタルサーバ向けメール DNS 設定（MX / SPF / DMARC / DKIM）を Terraform で管理する能力

### Modified Capabilities

（なし）

## Impact

- **Terraform cloudflare ワークスペース**: `dns_mail.tf` 追加・`variables.tf` 変数追加・`terraform.tfvars` 値追記
- **メール受信**: MX レコード追加後、`*@i-tk.dev` 宛メールがさくらのメールサーバへルーティングされる
- **メール送信**: SPF・DKIM 設定後、さくらのサーバから送信したメールがスパム判定されにくくなる
- **DMARC**: 受信側 MTA がレポートを送信するようになる（`rua` 設定次第）
- **Cloudflare メール設定との競合**: メール転送などの Cloudflare Email Routing が有効な場合は無効化が必要（前提: 現在は無効）
