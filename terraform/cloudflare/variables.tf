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

variable "sakura_mail_server" {
  type        = string
  description = "さくらのレンタルサーバのメールサーバホスト名（MX レコード値）"
}

variable "sakura_spf_txt" {
  type        = string
  description = "さくら向け SPF TXT レコードの値（さくらコントロールパネルで確認）"
}

variable "sakura_dmarc_rua" {
  type        = string
  description = "DMARC レポートの送信先メールアドレス"
}

variable "sakura_dkim_selector" {
  type        = string
  description = "さくら DKIM のセレクタ名"
  default     = "default"
}

variable "sakura_dkim_txt" {
  type        = string
  description = "さくら DKIM の TXT レコード値（v=DKIM1; k=rsa; p=...）。null の場合は DKIM レコードを作成しない"
  default     = null
}
