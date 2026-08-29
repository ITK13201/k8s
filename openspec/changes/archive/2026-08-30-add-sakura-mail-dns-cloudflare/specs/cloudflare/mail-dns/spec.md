## Purpose

`i-tk.dev` ドメインのメール配信をさくらのレンタルサーバへ委任するための DNS レコード群（MX・SPF・DMARC・DKIM）を Cloudflare 上で Terraform により宣言的に管理する能力。

## ADDED Requirements

### Requirement: MX レコードが設定されること

`i-tk.dev` ドメインに対して、さくらのレンタルサーバを指す MX レコードが Cloudflare に登録されていなければならない（SHALL）。  
MX レコードの `proxied` フラグは `false` であること（メールトラフィックは Cloudflare Proxy を通過できないため）。

#### Scenario: MX レコードが存在する

- **WHEN** `dig MX i-tk.dev` を実行する
- **THEN** さくらのメールサーバホスト名を指す MX レコードが返される

#### Scenario: MX レコードがプロキシ無効である

- **WHEN** Cloudflare ダッシュボードで `i-tk.dev` の MX レコードを確認する
- **THEN** プロキシ（オレンジ雲）が無効（グレー雲）になっている

### Requirement: SPF TXT レコードが設定されること

`i-tk.dev` に対して、さくらのサーバからの送信を許可する SPF TXT レコードが存在しなければならない（SHALL）。  
SPF レコードは `v=spf1 include:spf.sakura.ne.jp ~all` の形式であること。

#### Scenario: SPF レコードが存在する

- **WHEN** `dig TXT i-tk.dev` を実行する
- **THEN** `v=spf1` で始まる TXT レコードが返され、`include:spf.sakura.ne.jp` が含まれる

### Requirement: DMARC TXT レコードが設定されること

`_dmarc.i-tk.dev` に対して DMARC ポリシーを宣言する TXT レコードが存在しなければならない（SHALL）。  
ポリシーは `p=quarantine` 以上（quarantine または reject）であること。

#### Scenario: DMARC レコードが存在する

- **WHEN** `dig TXT _dmarc.i-tk.dev` を実行する
- **THEN** `v=DMARC1` で始まる TXT レコードが返され、`p=quarantine` または `p=reject` が含まれる

### Requirement: Terraform によって管理されること

上記の DNS レコードはすべて `terraform/cloudflare/dns_mail.tf` に定義され、`terraform apply` によって作成・更新されなければならない（SHALL）。  
メールサーバホスト名は変数（`var.sakura_mail_server`）として外部化され、ハードコードされてはならない。

#### Scenario: Terraform plan が差分なしとなる

- **WHEN** `terraform -chdir=terraform/cloudflare plan` を実行する
- **THEN** mail 用 DNS レコードについて "No changes" が報告される（apply 済み状態で）

#### Scenario: 変数ファイルにホスト名が定義されている

- **WHEN** `terraform/cloudflare/terraform.tfvars` を参照する
- **THEN** `sakura_mail_server` キーにさくらのメールサーバホスト名が設定されている
