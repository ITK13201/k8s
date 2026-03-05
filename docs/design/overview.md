# 設計概要: Proxmox VE 基盤への移行

## 背景

現状は CentOS Stream 9 上の 1 ノード構成（マスター＋ワーカー共存）。
Proxmox VE を導入し、コントロールプレーンとワーカーノードを VM として分離する。

## 全体フロー

```
[Proxmox VE]
    ↓ terraform apply  (bpg/proxmox)
[VM: control-plane × 1, worker × N]
    ↓ ansible-playbook
[k8s クラスタ]
    ↓ ArgoCD (既存・変更なし)
[アプリケーションデプロイ]
```

## ディレクトリ構成（変更後）

```
k8s/
├── terraform/                    # Proxmox VM プロビジョニング
│   ├── providers.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── control_plane.tf
│   ├── workers.tf
│   └── terraform.tfvars.example
├── ansible/                      # k8s インストール自動化
│   ├── inventory/
│   │   ├── hosts.yml
│   │   └── group_vars/
│   │       ├── all.yml
│   │       ├── control_plane.yml
│   │       └── workers.yml
│   ├── roles/
│   │   ├── common/
│   │   ├── containerd/
│   │   ├── k8s_node/
│   │   ├── k8s_control_plane/
│   │   └── k8s_worker/
│   ├── playbooks/
│   │   ├── site.yml
│   │   ├── control_plane.yml
│   │   └── workers.yml
│   └── requirements.yml
├── manifests/                    # 既存（ArgoCD 管理・変更なし）
├── secrets/                      # 既存
├── credentials/                  # 既存（gitignore）
├── bin/
│   ├── create_secrets.sh         # 既存
│   └── cronjobs/                 # 既存
│   # install_k8s.sh, create_k8s_cluster.sh は Ansible 移行後に削除
├── docs/
│   ├── design/                   # 本設計ドキュメント群
│   └── ...                       # 既存ドキュメント
└── etc/
```

## 移行手順

1. Proxmox VE をベアメタルにインストール（手動）
2. Cloud-Init テンプレート VM を Proxmox 上に作成（手動）
3. `terraform/` を実装 → `terraform apply` で VM 起動
4. `ansible/` を実装 → `ansible-playbook playbooks/site.yml` で k8s 構築
5. ArgoCD の接続先を新クラスタに切り替え
6. 旧クラスタを廃止、`bin/install_k8s.sh` / `bin/create_k8s_cluster.sh` を削除

## 詳細設計

- [Terraform 設計](terraform.md)
- [Ansible 設計](ansible.md)
