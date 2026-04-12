# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 概要

ArgoCD (GitOps) + Kustomize + Helm で管理する個人用 Kubernetes インフラリポジトリ。
`master`へのプッシュが ArgoCD によって自動同期（prune 有効）される。

**インフラ構成（Proxmox VE 移行後）**

| レイヤー | 技術 | 概要 |
|---------|------|------|
| 仮想化基盤 | Proxmox VE | 物理ホスト（12コア・46GB・SSD 256GB） |
| VM プロビジョニング | Terraform (bpg/proxmox) | control-plane × 1、worker × 1 |
| k8s インストール | Ansible | kubeadm + Calico CNI |
| アプリデプロイ | ArgoCD | `manifests/` を GitOps で管理 |

**VM スペック**

| VM | IP | CPU | メモリ | ディスク |
|----|----|-----|--------|---------|
| k8s-cp01 | 192.168.1.200 | 2コア | 8GB | 30GB |
| k8s-worker01 | 192.168.1.201 | 10コア | 32GB | 150GB |

Terraform state は Cloudflare R2 で管理。SSH 鍵は `~/.ssh/personal/pve/id_ed25519`。

## ドキュメント規約

**CLAUDE.md には最低限の情報のみ記載する。詳細はドメインごとに `docs/` 配下のファイルに記載すること。**

詳細は以下を参照すること。

- [アーキテクチャ・ディレクトリ構成](docs/architecture.md)
- [アプリケーション一覧・バージョン制約](docs/applications.md)
- [シークレット管理](docs/secrets.md)
- [ローカル開発 (Minikube)](docs/local-dev.md)
- [運用・バックアップ](docs/operations.md)
- [Terraform 手順](docs/terraform.md)（Proxmox VE VM プロビジョニング）
- [Ansible 手順](docs/ansible.md)（k8s インストール）
- [設計ドキュメント](docs/design/overview.md)（Proxmox VE 移行設計）
  - [Terraform 設計](docs/design/terraform.md)
  - [Ansible 設計](docs/design/ansible.md)
  - [Prometheus/Grafana 設計](docs/prometheus-grafana-design.md)
  - [Cloudflare Zero Trust 設計](docs/design/cloudflare-zero-trust.md)
  - [Terraform Cloudflare 設計](docs/design/terraform-cloudflare.md)
  - [メールサーバ設計](docs/design/mailserver.md)（docker-mailserver on k8s）
  - [シークレット管理 1Password 移行設計](docs/design/secrets-1password.md)（ESO + 1Password Connect）
  - [ログ集約設計](docs/design/logging.md)（Grafana Loki + Promtail）
- [インシデント記録](docs/incidents/)（障害・ネットワーク問題の事後分析）

## 主要コマンド

```bash
# マニフェストをローカルでレンダリング（Helm含む）
# kubectl kustomize ではなく standalone の kustomize を使うこと
kustomize build --enable-helm ./manifests/<app>/

# YAML フォーマット（.yamlfmt の設定を使用）
yamlfmt .

# Helm chart の values スキーマ確認（values を書く前に必ず実行）
helm show values <chart> --repo <repo-url> --version <version>

# Secretの再生成
./bin/create_secrets.sh

# Terraform Proxmox（R2バックエンドのため -backend-config が必須）
terraform -chdir=terraform/proxmox init -backend-config=backend.hcl
terraform -chdir=terraform/proxmox plan
terraform -chdir=terraform/proxmox apply
terraform -chdir=terraform/proxmox output -json   # VM の IP アドレス確認

# Terraform Cloudflare（独立したワークスペース）
terraform -chdir=terraform/cloudflare init -backend-config=backend.hcl
terraform -chdir=terraform/cloudflare plan
terraform -chdir=terraform/cloudflare apply

# Ansible（ansible.cfg の相対パス設定のため ansible/ ディレクトリから実行すること）
cd ansible/
ansible-galaxy collection install -r requirements.yml
ansible all -m ping                              # 接続確認
ansible-playbook playbooks/site.yml              # 全ノード
ansible-playbook playbooks/workers.yml           # ワーカーのみ
ansible-playbook playbooks/site.yml --check      # dry-run
ansible-lint roles/<role>/tasks/main.yml         # lint
```

## 重要な制約

### ArgoCD ApplicationSet の除外アプリ

以下のアプリは `manifests/argocd/application-set.yaml` で **明示的に除外** されており、ArgoCD による自動同期対象外:

| アプリ | 備考 |
|--------|------|
| `manifests/growi` | 更新は `./bin/update/update-growi.sh` を使うこと（[docs/operations.md](docs/operations.md) 参照） |
| `manifests/growi-converter` | 手動適用 |
| `manifests/minecraft` | 手動適用 |
| `manifests/palworld` | 手動適用 |

### マニフェストディレクトリの命名
- `manifests/ingress/` — 各アプリの **Ingress リソース**（argocd.yaml, grafana.yaml など）を集約
- `manifests/ingress-nginx/` — ingress-nginx **コントローラ**本体の Helm values・kustomization

### Kubernetes API バージョン
- HPA は必ず `autoscaling/v2` を使うこと（`autoscaling/v1` は k8s v1.26 以降削除済み）
- Helm chart が `autoscaling/v1` を生成する場合は `values.yaml` で HPA を無効化し、独自リソースとして `hpa.yaml` を追加する

### バージョン固定
- `kubernetes-dashboard`: **v6 を維持**（v6→v7 は非互換アップグレード）
- 詳細は [docs/applications.md](docs/applications.md) を参照

### kustomize helmCharts への namespace 非適用
- kustomize 5.8.1 では `namespace:` フィールドが `helmCharts:` で生成されるリソースに適用されない
- 回避策: `kustomization.yaml` 内に種類ごとの JSON6902 パッチを追加する
  ```yaml
  patches:
  - patch: '[{"op":"add","path":"/metadata/namespace","value":"<ns>"}]'
    target:
      kind: Deployment
  ```

### PersistentVolume 管理
- PV は `manifests/pv/` で定義し、`reclaimPolicy: Retain` を使用
- ホストパスはストレージ種別で異なる（`ansible/inventory/group_vars/workers/main.yml` の `server_setup_k8s_pv_dirs` に全一覧）:
  - **SSD** (`/data/k8s/pv/<app>/`): 高速I/Oが必要なもの（minecraft, palworld など）
  - **HDD** (`/mnt/hdd/data/k8s/pv/<app>/`): 大容量が必要なもの（nextcloud, growi, monitoring など）
- ディレクトリ作成は Ansible `server_setup` ロールの `server_setup_k8s_pv_dirs` 変数で管理
- PV が `Released` 状態になった場合は `claimRef` を手動で削除して `Available` に戻す:
  ```bash
  kubectl patch pv <name> --type=json -p='[{"op":"remove","path":"/spec/claimRef"}]'
  ```

### Cloudflare Terraform Provider v5 命名変更
- `cloudflare_record` → **`cloudflare_dns_record`**
- DNS レコードの値フィールド: `value` → **`content`**
- `cloudflare_zone_settings_override` 廃止 → **`cloudflare_zone_setting`**（設定1つにつき1リソース）
- 新規サービス追加時は `terraform/cloudflare/dns.tf` の `web_subdomains` リストに追加すること

### Ansible ロール変数命名規則
- ロール変数には必ずロール名プレフィックスを付ける: `rolename_varname`
- ロール内部変数（`register` など）はダブルアンダースコア: `rolename__varname`
- `ansible-lint` で検証すること

### Ansible シークレット管理
- `ansible/inventory/group_vars/workers.secret.yml` に機密変数を記載（gitignore 対象）
- テンプレートは `workers.secret.yml.example` を参照

### Renovate 自動マージポリシー

Renovate が以下を自動追跡する:
- YAML ファイル内の Docker イメージタグ
- `kustomization.yaml` 内の GitHub Release / GitHub raw URL

**non-0.x の minor/patch は自動マージ**。major バージョンアップは手動レビューが必要。

## Git コミット規約

- コミットメッセージの1行目（abstract）は**英語**で記載する
- 本文（description）は**日本語**で記載する
- Issue に紐づく作業の場合は、1行目の先頭に Issue 番号を付ける
  - 例: `#142 feat(terraform/cloudflare): manage DNS records`
  - 例: `#138 fix(ansible): fix playbook path`

## MCP サーバー利用ルール

- **Terraform** に関する作業を行う際は、**必ず Terraform MCP サーバー**経由で情報を取得すること。
- **Ansible** に関する作業を行う際は、**必ず Ansible MCP サーバー**経由で情報を取得すること。
- MCPサーバーから取得した情報を優先し、学習済みの古い知識に頼らないこと。
