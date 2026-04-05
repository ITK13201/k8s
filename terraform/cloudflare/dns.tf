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
  proxied = true
  ttl     = 1 # proxied 有効時は automatic（1）
}
