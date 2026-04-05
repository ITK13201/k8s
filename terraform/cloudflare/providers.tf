terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }

  # 値は backend.hcl で指定する（terraform init -backend-config=backend.hcl）
  backend "s3" {}
}

# DNS・ゾーン設定用（Zone:DNS:Edit, Zone:Zone Settings:Edit, Zone:Zone:Read）
provider "cloudflare" {
  api_token = var.cloudflare_dns_api_token
}

# R2 バケット管理用（Account:Cloudflare R2 Storage:Edit）
provider "cloudflare" {
  alias     = "r2"
  api_token = var.cloudflare_r2_api_token
}
