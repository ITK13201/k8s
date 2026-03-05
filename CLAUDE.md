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

## 主要コマンド

```bash
# マニフェストをローカルでレンダリング（Helm含む）
kubectl kustomize --enable-helm ./manifests/<app>/

# Secretの再生成
./bin/create_secrets.sh

# Terraform（R2バックエンドのため -backend-config が必須）
terraform -chdir=terraform init -backend-config=backend.hcl
terraform -chdir=terraform plan
terraform -chdir=terraform apply

# Ansible
ansible-galaxy collection install -r ansible/requirements.yml
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml
```

## MCP サーバー利用ルール

- **Terraform** に関する作業を行う際は、**必ず Terraform MCP サーバー**経由で情報を取得すること。
- **Ansible** に関する作業を行う際は、**必ず Ansible MCP サーバー**経由で情報を取得すること。
- MCPサーバーから取得した情報を優先し、学習済みの古い知識に頼らないこと。
