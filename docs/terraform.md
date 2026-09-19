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

### 共通（Makefile + 1Password 運用）

Terraform の操作はリポジトリルートの `Makefile` 経由で実行する（`make help` で一覧表示）。
秘密値・個人情報は 1Password（`op run --env-file`）から実行時にのみ子プロセスへ注入され、
親シェルやディスクには残らない。

- `op`（1Password CLI）がインストール済みかつサインイン済みであること（`op signin`）。
- vault `K8s` に必要なアイテム（`terraform-proxmox`・`terraform-cloudflare`・`cloudflare-r2`）が存在し、
  各フィールドに値が投入済みであること（雛形は本リポジトリの変更で作成、値の投入は手動）。
- 参照定義は `terraform/proxmox/env.op`・`terraform/cloudflare/env.op`（`op://` 参照のみ・コミット済み）。
- 非秘密・非個人のデフォルト（サイジング・`proxmox_username`・`datastore_id` 等）は
  `terraform/<workspace>/defaults.auto.tfvars`（コミット済み・`terraform` が自動読込）。

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

### 1Password への値投入（初回のみ）

vault `K8s` の `terraform-proxmox`・`cloudflare-r2` アイテムに実値を投入する
（R2 の access/secret key・endpoint、proxmox パスワード・endpoint・各種 IP・by-id・SSH 鍵等）。
参照先フィールドは `terraform/proxmox/env.op` を参照。backend の bucket/key/region 等の非秘密値は
`Makefile` の `-backend-config` フラグで供給されるため `backend.hcl` は不要。

### 初期化

```bash
# プロバイダーと R2 バックエンドを初期化（op 経由で認証情報を注入）
make tf-proxmox-init
```

## VM のプロビジョニング

```bash
# 変更内容を確認
make tf-proxmox-plan

# VM を作成
make tf-proxmox-apply
```

`apply` が完了すると以下のリソースが作成される:
- `rocky9-template`（VM ID: 9000）— Rocky Linux 9 テンプレート
- `k8s-cp01` — コントロールプレーン VM
- `k8s-worker01` — ワーカー VM

## Ansible inventory の更新

```bash
# IP アドレスを確認
make tf-proxmox-output

# 出力された IP を ansible/inventory/hosts.yml に反映する
```

## VM の削除

```bash
make tf-proxmox-destroy
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

vault `K8s` の `terraform-cloudflare`・`cloudflare-r2` アイテムに実値を投入する
（DNS/R2 API トークン・account_id・home_ip・さくらメール設定・DKIM、R2 の access/secret key・endpoint）。
参照先フィールドは `terraform/cloudflare/env.op` を参照。`backend.hcl`・`terraform.tfvars` は不要。

## 初期化・適用

```bash
make tf-cloudflare-init
make tf-cloudflare-plan
make tf-cloudflare-apply
```

## 既存リソースの import（初回のみ）

`import` も R2 バックエンド認証が必要なため `op run --env-file` 経由で実行する。

```bash
# R2 バケット
op run --env-file=terraform/cloudflare/env.op -- terraform -chdir=terraform/cloudflare import \
  'cloudflare_r2_bucket.tf_state' "<ACCOUNT_ID>/tf-state-k8s/default"

# 既存 DNS レコード（zone_id と record_id は Cloudflare API または dashboard から取得）
op run --env-file=terraform/cloudflare/env.op -- terraform -chdir=terraform/cloudflare import \
  'cloudflare_dns_record.web["argocd"]' "<ZONE_ID>/<RECORD_ID>"
```

