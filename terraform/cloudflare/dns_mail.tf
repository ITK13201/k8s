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
# sendgrid_dkim_cname が設定された場合のみ作成
# -----------------------------------------------
resource "cloudflare_dns_record" "sendgrid_dkim_em" {
  count = var.sendgrid_dkim_cname != null ? 1 : 0

  zone_id = local.zone_id
  name    = "${var.sendgrid_dkim_cname.em_name}._domainkey.i-tk.dev"
  type    = "CNAME"
  content = var.sendgrid_dkim_cname.em
  proxied = false
  ttl     = 3600
}

resource "cloudflare_dns_record" "sendgrid_dkim_s1" {
  count = var.sendgrid_dkim_cname != null ? 1 : 0

  zone_id = local.zone_id
  name    = "s1._domainkey.i-tk.dev"
  type    = "CNAME"
  content = var.sendgrid_dkim_cname.s1
  proxied = false
  ttl     = 3600
}

resource "cloudflare_dns_record" "sendgrid_dkim_s2" {
  count = var.sendgrid_dkim_cname != null ? 1 : 0

  zone_id = local.zone_id
  name    = "s2._domainkey.i-tk.dev"
  type    = "CNAME"
  content = var.sendgrid_dkim_cname.s2
  proxied = false
  ttl     = 3600
}
