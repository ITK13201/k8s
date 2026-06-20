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
| シークレット管理 | ESO + 1Password Connect | ExternalSecret CRD で 1Password から自動同期 |

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

## アプリケーション固有の注記

### Kubernetes Dashboard

v6→v7 は非互換のため v6 を維持する。

### Growi

v7.0.9 以降でエディタ画面に MongoDB 認証エラー（"Authentication Failed"）が発生するため v7.0.3 に固定。
v7.0.3〜v7.0.9 の中間バージョンは未確認。
