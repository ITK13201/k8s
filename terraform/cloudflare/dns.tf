data "cloudflare_zone" "itk_dev" {
  filter = {
    name = "i-tk.dev"
  }
}

locals {
  zone_id = data.cloudflare_zone.itk_dev.id

  # ingress-nginx 経由で公開する Web サービスのサブドメイン
  web_subdomains = [
    "argocd",
    "cloud",            # Nextcloud
    "growi",
    "growi-converter",
    "grafana",
    "prometheus",
    "alertmanager",
    "rss",              # rss-generator
    "rss-notifier",
  ]
}

# -----------------------------------------------
# A レコード: Web サービス（ingress-nginx 経由）
# -----------------------------------------------
resource "cloudflare_dns_record" "web" {
  for_each = toset(local.web_subdomains)

  zone_id = local.zone_id
  name    = "${each.key}.i-tk.dev"
  type    = "A"
  content = var.home_ip
  proxied = false
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
