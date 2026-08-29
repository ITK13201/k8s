# -----------------------------------------------
# メール DNS レコード（さくらのレンタルサーバ向け）
# -----------------------------------------------

resource "cloudflare_dns_record" "sakura_mx" {
  zone_id  = local.zone_id
  name     = "i-tk.dev"
  type     = "MX"
  content  = var.sakura_mail_server
  priority = 10
  proxied  = false
  ttl      = 300
}

resource "cloudflare_dns_record" "sakura_spf" {
  zone_id = local.zone_id
  name    = "i-tk.dev"
  type    = "TXT"
  content = var.sakura_spf_txt
  proxied = false
  ttl     = 300
}

resource "cloudflare_dns_record" "sakura_dmarc" {
  zone_id = local.zone_id
  name    = "_dmarc.i-tk.dev"
  type    = "TXT"
  content = "v=DMARC1; p=quarantine; aspf=r; adkim=r; rua=mailto:${var.sakura_dmarc_rua}"
  proxied = false
  ttl     = 300
}

resource "cloudflare_dns_record" "sakura_dkim" {
  count = var.sakura_dkim_txt != null ? 1 : 0

  zone_id = local.zone_id
  name    = "${var.sakura_dkim_selector}._domainkey.i-tk.dev"
  type    = "TXT"
  content = var.sakura_dkim_txt
  proxied = false
  ttl     = 300
}
