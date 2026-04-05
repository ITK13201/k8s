# -----------------------------------------------
# A レコード: メールサーバ（受信専用）
# -----------------------------------------------
resource "cloudflare_dns_record" "mail" {
  zone_id = local.zone_id
  name    = "mail.i-tk.dev"
  type    = "A"
  content = var.home_ip
  proxied = false # メールプロトコルは Cloudflare Proxy 非対応
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
# SPF（送信は Resend のみ許可）
# -----------------------------------------------
resource "cloudflare_dns_record" "spf" {
  zone_id = local.zone_id
  name    = "i-tk.dev"
  type    = "TXT"
  content = "v=spf1 include:amazonses.com -all"
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
# Resend ドメイン認証（DKIM・Return-Path）
# resend_dkim_txt が設定された場合のみ作成
# -----------------------------------------------
resource "cloudflare_dns_record" "resend_dkim" {
  count = var.resend_dkim_txt != null ? 1 : 0

  zone_id = local.zone_id
  name    = "resend._domainkey.i-tk.dev"
  type    = "TXT"
  content = var.resend_dkim_txt
  proxied = false
  ttl     = 3600
}

resource "cloudflare_dns_record" "resend_return_path_mx" {
  count = var.resend_dkim_txt != null ? 1 : 0

  zone_id  = local.zone_id
  name     = "send.i-tk.dev"
  type     = "MX"
  content  = "feedback-smtp.ap-northeast-1.amazonses.com"
  priority = 10
  proxied  = false
  ttl      = 3600
}

resource "cloudflare_dns_record" "resend_return_path_spf" {
  count = var.resend_dkim_txt != null ? 1 : 0

  zone_id = local.zone_id
  name    = "send.i-tk.dev"
  type    = "TXT"
  content = "v=spf1 include:amazonses.com ~all"
  proxied = false
  ttl     = 3600
}
