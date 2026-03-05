# Ansible 設計（k8s インストール）

## アプローチ選定

| 方式 | 概要 | 採否 |
|------|------|------|
| カスタム Ansible ロール | 自前でロールを実装 | **採用** |
| Kubespray | k8s 公式の Ansible playbook | 見送り（オーバースペック） |
| k3s-ansible | k3s 向け軽量 playbook | 見送り（フル k8s を維持） |

構成の完全な把握・制御を優先し、カスタムロールで実装する。
シンプルに始め、必要に応じて段階的に拡張する。

## ロール構成と責務

| ロール | 対象 | 責務 |
|--------|------|------|
| `common` | 全ノード | swap 無効化、sysctl、カーネルモジュール、タイムゾーン |
| `containerd` | 全ノード | containerd インストール・設定 |
| `k8s_node` | 全ノード | kubeadm / kubelet / kubectl インストール |
| `k8s_control_plane` | コントロールプレーン | `kubeadm init`、CNI (Calico) 適用 |
| `k8s_worker` | ワーカー | `kubeadm join`（`k8s_control_plane` の後に実行） |

## Playbook 構成

```yaml
# ansible/playbooks/site.yml
---
- import_playbook: control_plane.yml
- import_playbook: workers.yml
```

```yaml
# ansible/playbooks/control_plane.yml
---
- name: Set up control plane node
  hosts: control_plane
  become: true
  roles:
    - common
    - containerd
    - k8s_node
    - k8s_control_plane
```

```yaml
# ansible/playbooks/workers.yml
---
- name: Set up worker nodes
  hosts: workers
  become: true
  roles:
    - common
    - containerd
    - k8s_node
    - k8s_worker
```

## Inventory 構成

```yaml
# ansible/inventory/hosts.yml
all:
  children:
    control_plane:
      hosts:
        cp01:
          ansible_host: 192.168.x.x
    workers:
      hosts:
        worker01:
          ansible_host: 192.168.x.x
        worker02:
          ansible_host: 192.168.x.x
```

IP アドレスは `terraform output -json` の結果から手動で記入する。

## 変数設計

```yaml
# ansible/inventory/group_vars/all.yml
k8s_version: "1.32.x"
pod_network_cidr: "192.168.0.0/16"  # Calico デフォルト
containerd_version: "2.x.x"
```

- 変数名はロール名プレフィックスを付ける（例: `k8s_node_version`、`containerd_config_dir`）
- ロール内部変数はダブルアンダースコアプレフィックスを付ける（例: `__k8s_node_repo_url`）

## ベストプラクティス（Ansible MCP 準拠）

- ファイル拡張子は `.yml`（`.yaml` は使わない）
- ロール名・変数名は `snake_case`
- 全タスクに名前を付け、命令形で記述する
- ロール変数にはロール名プレフィックスを付ける
- `ansible-lint` で継続的に検証する

## 主要コマンド

```bash
# 全ノードに適用
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml

# コントロールプレーンのみ
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/control_plane.yml

# ワーカーのみ
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/workers.yml

# Dry-run（変更確認）
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml --check

# Galaxy コレクション・ロールのインストール
ansible-galaxy install -r ansible/requirements.yml
```
