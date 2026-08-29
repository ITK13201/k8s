## 1. 事前確認・さくら側 DKIM 設定

- [x] 1.1 Cloudflare ダッシュボードで i-tk.dev の Email Routing が無効になっていることを確認する（有効な場合は無効化する）
- [x] 1.2 さくらのコントロールパネル → ドメイン設定 → 「送信ドメイン認証（DKIM）」で i-tk.dev の DKIM を有効化し、提示されるセレクタ名と TXT レコード値（`v=DKIM1; k=rsa; p=...`）をメモする

## 2. Terraform 変数追加

- [x] 2.1 `terraform/cloudflare/variables.tf` に `sakura_mail_server`（string, 説明付き）変数を追加し、`terraform validate` でエラーがないことを確認する
- [x] 2.2 同ファイルに `sakura_dkim_selector`（string, default = `"default"`）と `sakura_dkim_txt`（string, nullable, default = `null`）変数を追加する
- [x] 2.3 `terraform/cloudflare/terraform.tfvars.example` に `sakura_mail_server` プレースホルダと DKIM 変数のコメントアウト例を追記する

## 3. dns_mail.tf 作成

- [x] 3.1 `terraform/cloudflare/dns_mail.tf` を新規作成し、MX レコード（`i-tk.dev`、priority 10、`var.sakura_mail_server`、`proxied = false`、`ttl = 300`）を定義する
- [x] 3.2 同ファイルに SPF TXT レコード（`i-tk.dev`、`v=spf1 include:spf.sakura.ne.jp ~all`、`proxied = false`、`ttl = 300`）を追加する
- [x] 3.3 同ファイルに DMARC TXT レコード（`_dmarc.i-tk.dev`、`v=DMARC1; p=quarantine; rua=mailto:ti2236sh@gmail.com`、`proxied = false`、`ttl = 300`）を追加する
- [x] 3.4 同ファイルに DKIM TXT レコードを条件付きで追加する（`count = var.sakura_dkim_txt != null ? 1 : 0`、レコード名は `${var.sakura_dkim_selector}._domainkey.i-tk.dev`、値は `var.sakura_dkim_txt`）
- [x] 3.5 `terraform -chdir=terraform/cloudflare validate` を実行し、エラーがないことを確認する

## 4. MX / SPF / DMARC を先に適用

- [x] 4.1 `terraform/cloudflare/terraform.tfvars` に `sakura_mail_server = "goldfawn75.sakura.ne.jp"` を追記する（`sakura_dkim_txt` はまだ追記しない）
- [x] 4.2 `terraform -chdir=terraform/cloudflare plan` を実行し、追加されるレコードが MX・SPF・DMARC の3件であることを確認する
- [x] 4.3 `terraform -chdir=terraform/cloudflare apply` を実行し、適用が成功することを確認する
- [x] 4.4 `dig MX i-tk.dev`・`dig TXT i-tk.dev`・`dig TXT _dmarc.i-tk.dev` で各レコードの反映を確認する

## 5. DKIM を追加適用

- [x] 5.1 タスク 1.2 で取得した TXT レコード値を `terraform/cloudflare/terraform.tfvars` に追記する（`sakura_dkim_selector`・`sakura_dkim_txt`）
- [x] 5.2 `terraform -chdir=terraform/cloudflare plan` で DKIM TXT レコード1件のみが追加されることを確認する
- [x] 5.3 `terraform -chdir=terraform/cloudflare apply` を実行し、適用が成功することを確認する
- [x] 5.4 `dig TXT rs20260829._domainkey.i-tk.dev` で DKIM レコードが返されることを確認する

## 6. 送受信テスト

- [x] 6.1 さくらのコントロールパネルまたはメールクライアントで `@i-tk.dev` アドレス宛にテストメールを送り、受信できることを確認する
- [x] 6.2 `@i-tk.dev` アドレスからテストメールを外部へ送り、スパム判定されないことを確認する（Gmail など受信側のヘッダで SPF/DKIM pass を確認）
