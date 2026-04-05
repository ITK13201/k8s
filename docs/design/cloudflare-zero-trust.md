# Cloudflare Zero Trust 設計書

## 概要

Cloudflare Access を使い、管理系サービスにログイン認証を追加する。
インフラ構成（ingress-nginx・ルーター設定）は変更しない。

Terraform 管理は [docs/design/terraform-cloudflare.md](terraform-cloudflare.md) の `terraform/cloudflare/` ワークスペースに `zero_trust.tf` を追加する。

## Access 保護設計

| サービス | ドメイン | 保護 | 理由 |
|---------|---------|------|------|
| ArgoCD | argocd.i-tk.dev | **要** | GitOps 制御 |
| Grafana | grafana.i-tk.dev | **要** | クラスタ監視 |
| Prometheus | prometheus.i-tk.dev | **要** | メトリクス漏洩防止 |
| Alertmanager | alertmanager.i-tk.dev | **要** | アラート設定 |
| Nextcloud | cloud.i-tk.dev | 不要 | 自前認証あり |
| Growi | growi.i-tk.dev | 不要 | 自前認証あり |
| rss-generator | rss.i-tk.dev | 不要 | 自前認証あり |
| rss-notifier | rss-notifier.i-tk.dev | 不要 | 自前認証あり |
| growi-converter | growi-converter.i-tk.dev | 不要 | 自前認証あり |

## Identity Provider

個人用途のためシンプルな **One-time PIN（OTP）** を使用する。
認証フロー: アクセス → メールアドレス入力 → OTP をメールで受信 → ログイン

## Terraform リソース設計

`terraform/cloudflare/zero_trust.tf` を追加する。

```hcl
# -----------------------------------------------
# Identity Provider（OTP）
# -----------------------------------------------
resource "cloudflare_zero_trust_access_identity_provider" "otp" {
  account_id = var.cloudflare_account_id
  name       = "One-time PIN"
  type       = "onetimepin"
}

# -----------------------------------------------
# Access Group（本人のみ許可）
# -----------------------------------------------
resource "cloudflare_zero_trust_access_group" "owner" {
  account_id = var.cloudflare_account_id
  name       = "owner"

  include = [{
    email = { email = var.owner_email }
  }]
}

# -----------------------------------------------
# Access Policy（管理系サービス共通）
# -----------------------------------------------
resource "cloudflare_zero_trust_access_policy" "admin" {
  account_id = var.cloudflare_account_id
  name       = "admin-only"
  decision   = "allow"

  include = [{
    group = { id = cloudflare_zero_trust_access_group.owner.id }
  }]
}

# -----------------------------------------------
# Access Applications（管理系サービス）
# -----------------------------------------------
resource "cloudflare_zero_trust_access_application" "argocd" {
  account_id       = var.cloudflare_account_id
  name             = "ArgoCD"
  domain           = "argocd.i-tk.dev"
  type             = "self_hosted"
  session_duration = "24h"
  allowed_idps     = [cloudflare_zero_trust_access_identity_provider.otp.id]

  policies = [{
    id         = cloudflare_zero_trust_access_policy.admin.id
    precedence = 1
  }]
}

resource "cloudflare_zero_trust_access_application" "grafana" {
  account_id       = var.cloudflare_account_id
  name             = "Grafana"
  domain           = "grafana.i-tk.dev"
  type             = "self_hosted"
  session_duration = "24h"
  allowed_idps     = [cloudflare_zero_trust_access_identity_provider.otp.id]

  policies = [{
    id         = cloudflare_zero_trust_access_policy.admin.id
    precedence = 1
  }]
}

resource "cloudflare_zero_trust_access_application" "prometheus" {
  account_id       = var.cloudflare_account_id
  name             = "Prometheus"
  domain           = "prometheus.i-tk.dev"
  type             = "self_hosted"
  session_duration = "24h"
  allowed_idps     = [cloudflare_zero_trust_access_identity_provider.otp.id]

  policies = [{
    id         = cloudflare_zero_trust_access_policy.admin.id
    precedence = 1
  }]
}

resource "cloudflare_zero_trust_access_application" "alertmanager" {
  account_id       = var.cloudflare_account_id
  name             = "Alertmanager"
  domain           = "alertmanager.i-tk.dev"
  type             = "self_hosted"
  session_duration = "24h"
  allowed_idps     = [cloudflare_zero_trust_access_identity_provider.otp.id]

  policies = [{
    id         = cloudflare_zero_trust_access_policy.admin.id
    precedence = 1
  }]
}
```

### variables.tf への追加

```hcl
variable "owner_email" {
  type        = string
  description = "Access 認証で許可するメールアドレス（管理者）"
}
```

### terraform.tfvars.example への追加

```hcl
owner_email = "your@email.com"
```

## セットアップ手順

1. `terraform apply` で Access アプリを作成
2. `argocd.i-tk.dev` にアクセスして OTP 認証画面が表示されることを確認

## 参考

- [Cloudflare Zero Trust Access Applications](https://developers.cloudflare.com/cloudflare-one/applications/configure-apps/)
- [Terraform Zero Trust リソース](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_access_application)
