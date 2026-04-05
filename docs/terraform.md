# Terraform 手順

## ワークスペース一覧

| ワークスペース | パス | 用途 |
|---|---|---|
| Proxmox | `terraform/proxmox/` | Proxmox VE 上の VM プロビジョニング |
| Cloudflare | `terraform/cloudflare/` | DNS レコード・R2 バケット・ゾーン設定 |

---

# Proxmox ワークスペース

設計の詳細は [docs/design/terraform.md](design/terraform.md) を参照すること。

## 前提条件

### Proxmox VE 側の設定（手動・初回のみ）

1. `local` ストレージで `snippets` コンテンツを有効化する
   - Proxmox UI → Datacenter → Storage → `local` → Edit → Content に `Snippets` を追加

2. API 認証情報を用意する（`root@pam` またはアクセス権を付与したユーザー）

## セットアップ

### Cloudflare R2 バケットの準備（初回のみ）

1. Cloudflare ダッシュボード → R2 → バケットを作成（例: `tf-state-k8s`）
2. R2 → Manage R2 API Tokens → トークンを作成
   - Permissions: **Admin Read & Write**（Object Read & Write では不可）
   - Bucket: 作成したバケットを指定
3. 発行された **Access Key ID** と **Secret Access Key** を控える
4. Cloudflare ダッシュボード右上のアカウント ID を確認する

### backend.hcl の作成

```bash
cp terraform/proxmox/backend.hcl.example terraform/proxmox/backend.hcl
# backend.hcl を編集して ACCOUNT_ID・ACCESS_KEY・SECRET_KEY を設定
```

### terraform.tfvars の作成

```bash
# terraform.tfvars は既に作成済み
# REPLACE_WITH_PROXMOX_PASSWORD と ssh_public_key を手動で編集する
```

### 初期化

```bash
# プロバイダーと R2 バックエンドを初期化
terraform -chdir=terraform/proxmox init -backend-config=backend.hcl
```

## VM のプロビジョニング

```bash
# 変更内容を確認
terraform -chdir=terraform/proxmox plan

# VM を作成
terraform -chdir=terraform/proxmox apply
```

`apply` が完了すると以下のリソースが作成される:
- `rocky9-template`（VM ID: 9000）— Rocky Linux 9 テンプレート
- `k8s-cp01` — コントロールプレーン VM
- `k8s-worker01` — ワーカー VM

## Ansible inventory の更新

```bash
# IP アドレスを確認
terraform -chdir=terraform/proxmox output -json

# 出力された IP を ansible/inventory/hosts.yml に反映する
```

## VM の削除

```bash
terraform -chdir=terraform/proxmox destroy
```

## トラブルシューティング

### cloud-init が適用されない

`local` ストレージの `snippets` が有効になっているか確認する。

### IP アドレスが取得できない

VM 内で `qemu-guest-agent` が起動しているか確認する。
起動していない場合は `cloud_init.tf` の `runcmd` が実行されていない可能性がある。
Proxmox のコンソールから直接ログインして状態を確認する。

### テンプレートのクローンがタイムアウトする

`workers.tf` の `clone.retries` を増やす（現在: `3`）。

---

# Cloudflare ワークスペース

設計の詳細は [docs/design/terraform-cloudflare.md](design/terraform-cloudflare.md) を参照すること。

## API トークンの準備

| 変数 | 権限 |
|---|---|
| `cloudflare_dns_api_token` | Zone > DNS > Edit, Zone > Zone Settings > Edit, Zone > Zone > Read |
| `cloudflare_r2_api_token` | R2 → Manage R2 API Tokens → **Admin Read & Write** |

## セットアップ

```bash
cp terraform/cloudflare/backend.hcl.example terraform/cloudflare/backend.hcl
# backend.hcl を編集（key は cloudflare/terraform.tfstate、R2 の認証情報を設定）

cp terraform/cloudflare/terraform.tfvars.example terraform/cloudflare/terraform.tfvars
# terraform.tfvars を編集（cloudflare_dns_api_token, cloudflare_r2_api_token, cloudflare_account_id, home_ip）
```

## 初期化・適用

```bash
terraform -chdir=terraform/cloudflare init -backend-config=backend.hcl
terraform -chdir=terraform/cloudflare plan
terraform -chdir=terraform/cloudflare apply
```

## 既存リソースの import（初回のみ）

```bash
# R2 バケット
terraform -chdir=terraform/cloudflare import \
  'cloudflare_r2_bucket.tf_state' "<ACCOUNT_ID>/tf-state-k8s/default"

# 既存 DNS レコード（zone_id と record_id は Cloudflare API または dashboard から取得）
terraform -chdir=terraform/cloudflare import \
  'cloudflare_dns_record.web["argocd"]' "<ZONE_ID>/<RECORD_ID>"
```

## SendGrid DKIM 設定（メールサーバ構築後）

SendGrid でドメイン認証完了後、`terraform.tfvars` に `sendgrid_dkim_cname` を追加して apply する。

```hcl
sendgrid_dkim_cname = {
  em_name = "emXXXXXX"
  em      = "emXXXXXX.i-tk.dev.dkim.sendgrid.net"
  s1      = "s1.domainkey.uXXXXXX.wl.sendgrid.net"
  s2      = "s2.domainkey.uXXXXXX.wl.sendgrid.net"
}
```
