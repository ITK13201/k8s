# terraform

Proxmox VE 上に Kubernetes VM をプロビジョニングする Terraform コードです。

詳細手順は [docs/terraform.md](../docs/terraform.md) を参照してください。

## 構成ファイル

| ファイル | 役割 |
|---------|------|
| `providers.tf` | bpg/proxmox プロバイダー・Cloudflare R2 バックエンド設定 |
| `variables.tf` | 変数定義 |
| `terraform.tfvars` | 変数値（gitignore 対象） |
| `terraform.tfvars.example` | tfvars のテンプレート |
| `backend.hcl` | R2 バックエンド認証情報（gitignore 対象） |
| `backend.hcl.example` | backend.hcl のテンプレート |
| `template.tf` | Rocky Linux 9 テンプレート VM（VM ID: 9000） |
| `cloud_init.tf` | cloud-init スニペット |
| `control_plane.tf` | コントロールプレーン VM（k8s-cp01） |
| `workers.tf` | ワーカー VM（k8s-worker01） |
| `outputs.tf` | VM の IP アドレス出力 |

## クイックスタート

```bash
# 初回のみ: テンプレートからファイルを作成
cp backend.hcl.example backend.hcl
# backend.hcl を編集して Cloudflare R2 の認証情報を設定

# 初期化（リポジトリルートから実行）
terraform -chdir=terraform init -backend-config=backend.hcl

# 変更確認
terraform -chdir=terraform plan

# 適用
terraform -chdir=terraform apply

# VM の IP アドレス確認
terraform -chdir=terraform output -json
```
