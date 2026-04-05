variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "cloudflare_account_id" {
  type        = string
  description = "Cloudflare アカウント ID"
}

variable "home_ip" {
  type        = string
  description = "自宅グローバル IP アドレス"
}

variable "owner_email" {
  type        = string
  description = "Access 認証で許可するメールアドレス（管理者）。Cloudflare Zero Trust 設定時に使用"
  default     = null
}

variable "sendgrid_dkim_cname" {
  type = object({
    em_name = string
    em      = string
    s1      = string
    s2      = string
  })
  description = "SendGrid ドメイン認証で発行される CNAME レコード値。未設定の場合 DKIM レコードはスキップされる"
  default     = null
}
