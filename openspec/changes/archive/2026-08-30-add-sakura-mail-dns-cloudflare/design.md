## Context

`terraform/cloudflare/` ワークスペースで Cloudflare v5 Provider を使用して DNS を管理している。  
Web サービス用 A レコードは `dns.tf` にまとめられているが、メール用 DNS レコード（MX / SPF / DMARC）は 2026-08-29 の mailserver 削除時に `dns_mail.tf` ごと削除された。  
今回はさくらのレンタルサーバへメールを委任するため、同ファイルを新規作成する。

参照: proposal.md — Why

## Goals / Non-Goals

**Goals:**
- `dns_mail.tf` を新規作成し、MX・SPF・DMARC レコードを Terraform 管理下に置く
- メールサーバホスト名を変数化し、ハードコードを避ける
- `terraform.tfvars.example` にプレースホルダを追記し、設定方法を明示する

**Non-Goals:**
- Cloudflare Email Routing の設定（Sakura レンタルサーバとは別機能）
- さくら側のメールアカウント作成・設定
- SMTP/IMAP クライアント設定

## Decisions

### ファイル分割: dns_mail.tf を新規作成

Web サービス用 `dns.tf` とメール用レコードを同居させると見通しが悪くなるため、`dns_mail.tf` として分離する。  
前回の実装でも同名ファイルが存在していたことから、この命名が本プロジェクトの慣習に合致する。

### DKIM: さくらで有効化してから Terraform に追加

さくらの DKIM は、コントロールパネルで i-tk.dev ドメインの DKIM を有効化することで、さくら側がキーペアを生成し DNS 用の TXT レコード値（セレクタ名 + 公開鍵）を提示する仕組み。  
先にさくら側の設定を行い、提示された値を Terraform 変数として投入する流れとする。

変数は2つ設ける:
- `sakura_dkim_selector`: セレクタ名（さくらは `default` が一般的）、default = `"default"`
- `sakura_dkim_txt`: DKIM TXT レコード値（`v=DKIM1; k=rsa; p=...`）、default = `null`

`sakura_dkim_txt != null` の場合のみ `<selector>._domainkey.i-tk.dev` に TXT レコードを作成する（`count = var.sakura_dkim_txt != null ? 1 : 0`）。  
今回の実装では Terraform コードのみ先に用意し、さくら側設定完了後に `tfvars` へ値を追記して `terraform apply` する。

### プロキシ設定: proxied = false

メールトラフィック（SMTP/IMAP/POP3）は Cloudflare のリバースプロキシを通過できないため、MX・SPF・DMARC レコードはすべて `proxied = false` とする。

### TTL: 300 秒

メール DNS レコードは `proxied = false` のため TTL を手動指定する必要がある。  
標準的な 300 秒（5分）を採用し、DNS 伝播と変更追従のバランスをとる。

### DMARC ポリシー: quarantine

`none`（モニタリングのみ）より安全で、`reject`（完全拒否）より移行リスクが低い `quarantine` を採用する。  
SPF・DKIM が安定したあとで `reject` へ昇格させることを推奨する。

## Risks / Trade-offs

- **MX 設定前に既存メールが届かない**: i-tk.dev 宛のメールが現在どこへも届いていない状態のため、MX 追加はリスク低。ただし DNS 伝播（最大 48 時間、TTL 300 秒なら数分）の間は届かない場合あり。
- **SPF と Cloudflare Email Routing の競合**: Cloudflare Email Routing が有効な場合、SPF レコードの include が重複する可能性がある。事前に Cloudflare ダッシュボードで Email Routing 設定を確認・無効化すること。
- **DKIM 設定の順序依存**: さくら側で DKIM を有効化する前に Terraform apply すると DKIM レコードがない状態で適用される。MX/SPF/DMARC を先に適用し、さくら DKIM 設定後に DKIM レコードを追加する2段階運用で対応する。

## Migration Plan

1. さくらのコントロールパネルで以下を実施・確認する
   - メールサーバホスト名（MX レコード値）: `goldfawn75.sakura.ne.jp`（確認済み）
   - DKIM 設定を有効化し、提示されるセレクタ名と TXT レコード値をメモする
2. `terraform/cloudflare/terraform.tfvars` に `sakura_mail_server` を追記
3. `terraform -chdir=terraform/cloudflare plan` で差分確認
4. `terraform -chdir=terraform/cloudflare apply` で適用
5. `dig MX i-tk.dev` で MX レコードの反映を確認
6. さくらのコントロールパネルでメールアカウントに `@i-tk.dev` を設定
7. テストメール送受信で動作確認

**ロールバック**: `dns_mail.tf` を削除して `terraform apply` するだけで全メール DNS レコードが削除される。

## Open Questions

- DKIM TXT 値: さくらのコントロールパネルで DKIM を有効化してから提示される公開鍵の値。実装フェーズで取得し `terraform.tfvars` に追記する。
