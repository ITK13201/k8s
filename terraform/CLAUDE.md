# CLAUDE.md — terraform/

Terraform で管理するインフラリソース。Proxmox VE VM プロビジョニングと Cloudflare DNS/設定の2ワークスペースに分かれる。

詳細は [docs/terraform.md](../docs/terraform.md) および [docs/design/terraform.md](../docs/design/terraform.md) を参照。

## コマンド

```bash
# Terraform Proxmox（R2バックエンドのため -backend-config が必須）
terraform -chdir=terraform/proxmox init -backend-config=backend.hcl
terraform -chdir=terraform/proxmox plan
terraform -chdir=terraform/proxmox apply
terraform -chdir=terraform/proxmox output -json   # VM の IP アドレス確認

# Terraform Cloudflare（独立したワークスペース）
terraform -chdir=terraform/cloudflare init -backend-config=backend.hcl
terraform -chdir=terraform/cloudflare plan
terraform -chdir=terraform/cloudflare apply
```

## Cloudflare Terraform Provider v5 命名変更

- `cloudflare_record` → **`cloudflare_dns_record`**
- DNS レコードの値フィールド: `value` → **`content`**
- `cloudflare_zone_settings_override` 廃止 → **`cloudflare_zone_setting`**（設定1つにつき1リソース）
- 新規サービス追加時は `cloudflare/dns.tf` の `web_subdomains` リストに追加すること
