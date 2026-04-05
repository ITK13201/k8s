# Terraform 設計（Cloudflare）

## 概要

現在手動管理している Cloudflare リソース（DNS レコード・R2 バケット・ゾーン設定）を Terraform で管理する。
既存の Proxmox 用 `terraform/` とは独立した `terraform/cloudflare/` ワークスペースとして構築する。

## 管理対象リソース

| リソース | 概要 |
|---------|------|
| DNS レコード（A / MX / TXT / CNAME） | 全サブドメイン・SPF・DMARC・DKIM |
| R2 バケット | Terraform state 用バケット（`tf-state-k8s`） |
| ゾーン設定 | SSL モード、HTTPS 強制など |

## Provider

`cloudflare/cloudflare` v5 を使用する。

> **v4 → v5 の主な変更点**
> - `cloudflare_record` → `cloudflare_dns_record` にリネーム
> - DNS レコードの値フィールドが `value` → `content` にリネーム
> - `cloudflare_zone_settings_override` 廃止 → `cloudflare_zone_setting`（設定 1 つにつき 1 リソース）

```hcl
# terraform/cloudflare/providers.tf
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }

  backend "s3" {}
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
```

## ディレクトリ構成

```
terraform/cloudflare/
├── providers.tf              # Provider・backend 設定
├── variables.tf              # 変数定義
├── outputs.tf                # ゾーン ID など
├── dns.tf                    # DNS レコード（A / MX / TXT / CNAME）
├── r2.tf                     # R2 バケット
├── zone_settings.tf          # ゾーン設定
├── backend.hcl.example       # バックエンド設定テンプレート
└── terraform.tfvars.example  # 変数テンプレート（実値は gitignore）
```

## State 管理

既存の Proxmox state とは **別キー**で同一 R2 バケットに保存する。

```hcl
# terraform/cloudflare/backend.hcl（gitignore 対象）
bucket                      = "tf-state-k8s"
key                         = "cloudflare/terraform.tfstate"
region                      = "auto"
endpoint                    = "https://<ACCOUNT_ID>.r2.cloudflarestorage.com"
access_key                  = "<R2_ACCESS_KEY>"
secret_key                  = "<R2_SECRET_KEY>"
skip_credentials_validation = true
skip_metadata_api_check     = true
skip_region_validation      = true
force_path_style            = true
```

## マニフェスト詳細

### variables.tf

```hcl
variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "cloudflare_zone_id" {
  type        = string
  description = "i-tk.dev のゾーン ID（Cloudflare ダッシュボードで確認）"
}

variable "home_ip" {
  type        = string
  description = "自宅グローバル IP アドレス"
}

variable "cloudflare_account_id" {
  type        = string
  description = "Cloudflare アカウント ID"
}

variable "sendgrid_dkim_cname" {
  type = object({
    em      = string  # em<number>._domainkey の値
    s1      = string  # s1._domainkey の値
    s2      = string  # s2._domainkey の値
    em_name = string  # em<number> 部分の名前
  })
  description = "SendGrid ドメイン認証で発行される CNAME レコード値"
}
```

### dns.tf

```hcl
# ゾーンデータ取得
data "cloudflare_zone" "itk_dev" {
  filter = {
    name = "i-tk.dev"
  }
}

locals {
  zone_id = data.cloudflare_zone.itk_dev.id
}

# -----------------------------------------------
# A レコード: Web サービス（ingress-nginx 経由）
# -----------------------------------------------
locals {
  web_subdomains = [
    "argocd",
    "cloud",        # Nextcloud
    "growi",
    "growi-converter",
    "grafana",
    "prometheus",
    "alertmanager",
    "rss",          # rss-generator
    "rss-notifier",
  ]
}

resource "cloudflare_dns_record" "web" {
  for_each = toset(local.web_subdomains)

  zone_id = local.zone_id
  name    = "${each.key}.i-tk.dev"
  type    = "A"
  content = var.home_ip
  proxied = false  # HTTPS は ingress-nginx + cert-manager で終端するため
  ttl     = 300
}

# -----------------------------------------------
# A レコード: メールサーバ（受信専用）
# -----------------------------------------------
resource "cloudflare_dns_record" "mail" {
  zone_id = local.zone_id
  name    = "mail.i-tk.dev"
  type    = "A"
  content = var.home_ip
  proxied = false  # メールプロトコルは Cloudflare Proxy 非対応
  ttl     = 300
}

# -----------------------------------------------
# MX レコード
# -----------------------------------------------
resource "cloudflare_dns_record" "mx" {
  zone_id  = local.zone_id
  name     = "i-tk.dev"
  type     = "MX"
  content  = "mail.i-tk.dev"
  priority = 10
  proxied  = false
  ttl      = 3600
}

# -----------------------------------------------
# SPF（送信は SendGrid のみ許可）
# -----------------------------------------------
resource "cloudflare_dns_record" "spf" {
  zone_id = local.zone_id
  name    = "i-tk.dev"
  type    = "TXT"
  content = "v=spf1 include:sendgrid.net -all"
  proxied = false
  ttl     = 3600
}

# -----------------------------------------------
# DMARC
# -----------------------------------------------
resource "cloudflare_dns_record" "dmarc" {
  zone_id = local.zone_id
  name    = "_dmarc.i-tk.dev"
  type    = "TXT"
  content = "v=DMARC1; p=quarantine; rua=mailto:postmaster@i-tk.dev"
  proxied = false
  ttl     = 3600
}

# -----------------------------------------------
# SendGrid DKIM CNAME（ドメイン認証）
# -----------------------------------------------
resource "cloudflare_dns_record" "sendgrid_dkim_em" {
  zone_id = local.zone_id
  name    = "${var.sendgrid_dkim_cname.em_name}._domainkey.i-tk.dev"
  type    = "CNAME"
  content = var.sendgrid_dkim_cname.em
  proxied = false
  ttl     = 3600
}

resource "cloudflare_dns_record" "sendgrid_dkim_s1" {
  zone_id = local.zone_id
  name    = "s1._domainkey.i-tk.dev"
  type    = "CNAME"
  content = var.sendgrid_dkim_cname.s1
  proxied = false
  ttl     = 3600
}

resource "cloudflare_dns_record" "sendgrid_dkim_s2" {
  zone_id = local.zone_id
  name    = "s2._domainkey.i-tk.dev"
  type    = "CNAME"
  content = var.sendgrid_dkim_cname.s2
  proxied = false
  ttl     = 3600
}
```

### r2.tf

```hcl
# 既存バケットは import で取り込む
resource "cloudflare_r2_bucket" "tf_state" {
  account_id = var.cloudflare_account_id
  name       = "tf-state-k8s"
  location   = "apac"
}
```

### zone_settings.tf

```hcl
resource "cloudflare_zone_setting" "ssl" {
  zone_id    = local.zone_id
  setting_id = "ssl"
  value      = "full"
}

resource "cloudflare_zone_setting" "always_use_https" {
  zone_id    = local.zone_id
  setting_id = "always_use_https"
  value      = "on"
}

resource "cloudflare_zone_setting" "min_tls_version" {
  zone_id    = local.zone_id
  setting_id = "min_tls_version"
  value      = "1.2"
}
```

### outputs.tf

```hcl
output "zone_id" {
  value       = local.zone_id
  description = "i-tk.dev のゾーン ID"
}
```

## terraform.tfvars.example

```hcl
cloudflare_api_token  = "REPLACE_WITH_CLOUDFLARE_API_TOKEN"
cloudflare_zone_id    = "REPLACE_WITH_ZONE_ID"
cloudflare_account_id = "REPLACE_WITH_ACCOUNT_ID"
home_ip               = "REPLACE_WITH_HOME_IP"

sendgrid_dkim_cname = {
  em_name = "emXXXXXX"
  em      = "emXXXXXX.i-tk.dev.dkim.sendgrid.net"
  s1      = "s1.domainkey.uXXXXXX.wl.sendgrid.net"
  s2      = "s2.domainkey.uXXXXXX.wl.sendgrid.net"
}
```

## Cloudflare API トークンの権限

| 権限 | 理由 |
|------|------|
| Zone > DNS > Edit | DNS レコードの CRUD |
| Zone > Zone Settings > Edit | ゾーン設定の変更 |
| Zone > Zone > Read | ゾーン ID の参照 |
| Account > Cloudflare R2 Storage > Edit | R2 バケットの管理 |

## 既存リソースの Import 手順

Cloudflare に既に存在するリソースは `terraform import` で取り込む。

```bash
# 初期化
terraform -chdir=terraform/cloudflare init -backend-config=backend.hcl

# R2 バケットの import
terraform -chdir=terraform/cloudflare import \
  cloudflare_r2_bucket.tf_state "<ACCOUNT_ID>/tf-state-k8s"

# DNS レコードの import（zone_id/record_id の形式）
# レコード ID は Cloudflare API または dashboard URL から取得
terraform -chdir=terraform/cloudflare import \
  'cloudflare_dns_record.web["argocd"]' "<ZONE_ID>/<RECORD_ID>"
```

> **Tip**: 既存レコードが多い場合は `terraform import` を手動で繰り返すより、
> 先に `terraform plan` を実行して差分を確認し、不足分を `import` するほうが効率的。

## 運用コマンド

```bash
# 初期化
terraform -chdir=terraform/cloudflare init -backend-config=backend.hcl

# 差分確認
terraform -chdir=terraform/cloudflare plan

# 適用
terraform -chdir=terraform/cloudflare apply

# フォーマット
terraform fmt terraform/cloudflare/
```

## 新規アプリ追加時の手順

新しいサービスを `manifests/` に追加する際は、`dns.tf` の `web_subdomains` リストにサブドメインを追加して `apply` する。

## 参考

- [Cloudflare Terraform Provider v5 ドキュメント](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)
- [v4 → v5 マイグレーションガイド](https://github.com/cloudflare/terraform-provider-cloudflare/blob/master/docs/guides/version-5-upgrade.md)
