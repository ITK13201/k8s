# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 重要な方針

**CLAUDE.md は最小限に保つ。** ルートの CLAUDE.md には横断的な情報のみ記載し、詳細は各ディレクトリの CLAUDE.md および `docs/` 配下のファイルに分散して記載する。

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

## ディレクトリ別 CLAUDE.md

各ディレクトリ固有のガイダンスは以下を参照:

- [manifests/CLAUDE.md](manifests/CLAUDE.md) — Kubernetes マニフェスト管理（ArgoCD, Kustomize, Helm, PV, Tailscale, Renovate）
- [terraform/CLAUDE.md](terraform/CLAUDE.md) — Terraform によるインフラプロビジョニング（Proxmox, Cloudflare）
- [ansible/CLAUDE.md](ansible/CLAUDE.md) — Ansible による k8s クラスタ構築・設定

## ドキュメント

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
  - [MoneyRabbit デプロイ設計](docs/design/moneyrabbit.md)（家計管理PWAアプリ・Tailscale VPN限定）
  - [ファイル整理設計](docs/design/cleanup.md)（Proxmox VE 移行後の不要ファイル・スクリプト整理計画）
- [インシデント記録](docs/incidents/)（障害・ネットワーク問題の事後分析）

## 共通コマンド

```bash
# 開発環境（全ツールを提供）
nix develop  # kubectl, helm, kustomize, argocd, terraform, ansible-lint, yamlfmt が使用可能になる

# YAML フォーマット（.yamlfmt 設定: indentless_arrays: true が強制）
yamlfmt .
```

シークレット管理は ESO + 1Password Connect に移行済み。詳細は [docs/secrets.md](docs/secrets.md) を参照。

## バージョン管理

Renovate が non-0.x マイナー/パッチを PR squash automerge で自動更新する。
手動管理（Renovate 対象外）: growi, growi-converter, minecraft, palworld

## Git コミット規約

- コミットメッセージの1行目（abstract）は**英語**で記載する
- 本文（description）は**日本語**で記載する
- Issueに紐づく作業の場合は、1行目の先頭にIssue番号を付ける
  - 例: `#142 feat(terraform/cloudflare): manage DNS records`
  - 例: `#138 fix(ansible): fix playbook path`

## MCP サーバー利用ルール

- **Terraform** に関する作業を行う際は、**必ず Terraform MCP サーバー**経由で情報を取得すること。
- **Ansible** に関する作業を行う際は、**必ず Ansible MCP サーバー**経由で情報を取得すること。
- MCPサーバーから取得した情報を優先し、学習済みの古い知識に頼らないこと。
