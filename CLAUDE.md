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

## 主要コマンド

```bash
# マニフェストをローカルでレンダリング（Helm含む）
# kubectl kustomize ではなく standalone の kustomize を使うこと
kustomize build --enable-helm ./manifests/<app>/

# YAML フォーマット（.yamlfmt の設定を使用）
yamlfmt .

# Secretの再生成
./bin/create_secrets.sh

# Terraform（R2バックエンドのため -backend-config が必須）
terraform -chdir=terraform init -backend-config=backend.hcl
terraform -chdir=terraform plan
terraform -chdir=terraform apply
terraform -chdir=terraform output -json   # VM の IP アドレス確認

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

### Kubernetes API バージョン
- HPA は必ず `autoscaling/v2` を使うこと（`autoscaling/v1` は k8s v1.26 以降削除済み）
- Helm chart が `autoscaling/v1` を生成する場合は `values.yaml` で HPA を無効化し、独自リソースとして `hpa.yaml` を追加する

### バージョン固定
- `kubernetes-dashboard`: **v6 を維持**（v6→v7 は非互換アップグレード）
- 詳細は [docs/applications.md](docs/applications.md) を参照

### Ansible ロール変数命名規則
- ロール変数には必ずロール名プレフィックスを付ける: `rolename_varname`
- ロール内部変数（`register` など）はダブルアンダースコア: `rolename__varname`
- `ansible-lint` で検証すること

### Ansible シークレット管理
- `ansible/inventory/group_vars/workers.secret.yml` に機密変数を記載（gitignore 対象）
- テンプレートは `workers.secret.yml.example` を参照

## Git コミット規約

- コミットメッセージの1行目（abstract）は**英語**で記載する
- 本文（description）は**日本語**で記載する

## MCP サーバー利用ルール

- **Terraform** に関する作業を行う際は、**必ず Terraform MCP サーバー**経由で情報を取得すること。
- **Ansible** に関する作業を行う際は、**必ず Ansible MCP サーバー**経由で情報を取得すること。
- MCPサーバーから取得した情報を優先し、学習済みの古い知識に頼らないこと。
