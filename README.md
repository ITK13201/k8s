# Kubernetes Infrastructure

Proxmox VE + ArgoCD + Kustomize + Helm で管理する個人用 Kubernetes インフラ。
`master` へのプッシュが ArgoCD によって自動同期（prune 有効）される。

## インフラ構成

| レイヤー | 技術 | 概要 |
|---------|------|------|
| 仮想化基盤 | Proxmox VE | 物理ホスト（12コア・46GB・SSD 256GB） |
| VM プロビジョニング | Terraform (bpg/proxmox) | control-plane × 1、worker × 1 |
| k8s インストール | Ansible | kubeadm + Calico CNI |
| アプリデプロイ | ArgoCD | `manifests/` を GitOps で管理 |

## VM スペック

| VM | IP | CPU | メモリ | ディスク |
|----|----|-----|--------|---------|
| k8s-cp01 | 192.168.1.200 | 2コア | 8GB | 30GB |
| k8s-worker01 | 192.168.1.201 | 10コア | 32GB | 150GB |

## ドキュメント

- [アーキテクチャ・ディレクトリ構成](docs/architecture.md)
- [アプリケーション一覧・バージョン制約](docs/applications.md)
- [シークレット管理](docs/secrets.md)
- [ローカル開発 (Minikube)](docs/local-dev.md)
- [運用・バックアップ](docs/operations.md)
- [Terraform 手順](docs/terraform.md)
- [Ansible 手順](docs/ansible.md)

## Application-specific notes

### Kubernetes Dashboard

Keep v6 for a while because v6 -> v7 update is not compatible.

### Growi

Mongo DB error "Authentication Failed" (confirmed in Growi's application log) occurs in the editor screen with v7.0.9 or higher, so the version is left at v7.0.3.
Versions between v7.0.3 and v7.0.9 are unconfirmed.
