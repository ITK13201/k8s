variable "cloudflare_dns_api_token" {
  type        = string
  sensitive   = true
  description = "DNS・ゾーン設定用 API トークン（Zone:DNS:Edit, Zone:Zone Settings:Edit, Zone:Zone:Read）"
}

variable "cloudflare_r2_api_token" {
  type        = string
  sensitive   = true
  description = "R2 バケット管理用 API トークン（Account:Cloudflare R2 Storage:Edit）"
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

variable "resend_dkim_txt" {
  type        = string
  description = "Resend ドメイン認証で発行される DKIM TXT レコード値（p=...）。未設定の場合 DKIM レコードはスキップされる"
  default     = null
}
