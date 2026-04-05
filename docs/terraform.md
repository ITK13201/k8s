# Terraform 手順（Proxmox VE VM プロビジョニング）

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
   - Permissions: Object Read & Write
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
