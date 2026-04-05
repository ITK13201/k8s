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

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
