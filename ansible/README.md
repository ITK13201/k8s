# ansible

Kubernetes クラスタを VM 上にセットアップする Ansible コードです。

詳細手順は [docs/ansible.md](../docs/ansible.md) を参照してください。

## 前提条件

- Terraform で VM が起動済みであること
- `inventory/hosts.yml` の IP アドレスが `terraform output` の値と一致していること

## 構成

```
inventory/
  hosts.yml           # インベントリ（ホスト定義）
  group_vars/
    all.yml           # 共通変数（k8s バージョン・Pod CIDR 等）
    control_plane.yml
    workers.yml
playbooks/
  site.yml            # 全ノード一括セットアップ
  control_plane.yml   # コントロールプレーンのみ
  workers.yml         # ワーカーのみ
roles/
  common/             # swap無効化・sysctl・カーネルモジュール・SELinux
  containerd/         # containerdインストール・設定
  k8s_node/           # kubeadm / kubelet / kubectlインストール
  k8s_control_plane/  # kubeadm init・Calico CNI
  k8s_worker/         # kubeadm join
  argocd/             # ArgoCDデプロイ（kubectl apply -k manifests/argocd/）
playbooks/
  argocd.yml          # ArgoCDのみデプロイ
requirements.yml      # Galaxyコレクション定義
```

## クイックスタート

```bash
# 依存コレクションのインストール（初回のみ）
ansible-galaxy collection install -r ansible/requirements.yml

# 接続確認
ansible all -i ansible/inventory/hosts.yml -m ping

# クラスタ構築
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml

# dry-run
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml --check
```
