# Ansible 手順（k8s インストール）

設計の詳細は [docs/design/ansible.md](design/ansible.md) を参照すること。

## 前提条件

- Terraform で VM が起動済みであること（[docs/terraform.md](terraform.md) を参照）
- 実行マシンに Ansible がインストール済みであること
- `ansible/inventory/hosts.yml` の IP アドレスが Terraform output と一致していること
- VM への SSH 公開鍵認証が通ること

## セットアップ

```bash
# Ansible Galaxy コレクションをインストール
ansible-galaxy collection install -r ansible/requirements.yml

# 接続確認
ansible all -i ansible/inventory/hosts.yml -m ping
```

## k8s クラスタの構築

```bash
# コントロールプレーン＋ワーカーを一括セットアップ
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml

# コントロールプレーンのみ
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/control_plane.yml

# ワーカーのみ（コントロールプレーン構築済みの場合）
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/workers.yml
```

## クラスタの確認

```bash
# コントロールプレーンに SSH してノード状態を確認
ssh k8s@<control_plane_ip>
kubectl get nodes
```

正常時の出力例:
```
NAME          STATUS   ROLES           AGE   VERSION
k8s-cp01      Ready    control-plane   5m    v1.32.x
k8s-worker01  Ready    <none>          3m    v1.32.x
```

## kubeconfig の取得

`site.yml` 完了後、手元のマシンで kubectl を使えるようにするため kubeconfig を取得する。

```bash
scp k8s@192.168.1.200:~/.kube/config ~/.kube/config
```

## ロールごとの責務

| ロール | 対象 | 主な処理 |
|--------|------|---------|
| `common` | 全ノード | swap 無効化・sysctl・カーネルモジュール・SELinux permissive |
| `containerd` | 全ノード | Docker CE repo → containerd インストール・SystemdCgroup 有効化 |
| `k8s_node` | 全ノード | kubeadm / kubelet / kubectl インストール |
| `k8s_control_plane` | CP のみ | `kubeadm init`・Calico CNI 適用・kubeconfig 配置 |
| `k8s_worker` | Worker のみ | `kubeadm join` |
| `argocd` | CP のみ | `kubectl apply -k manifests/argocd/` で ArgoCD をデプロイ |
| `server_setup` | Worker のみ | discord-bot-cli インストール・リポジトリ clone・cron 設定 |

## Dry-run（変更確認）

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml --check
```

## トラブルシューティング

### containerd が起動しない

`/etc/containerd/config.toml` に `SystemdCgroup = true` が設定されているか確認する。

```bash
sudo grep SystemdCgroup /etc/containerd/config.toml
```

### kubeadm init が失敗する

swap が無効になっているか、カーネルモジュールがロードされているか確認する。

```bash
free -h                          # swap が 0 であること
lsmod | grep -E 'overlay|br_netfilter'
sysctl net.ipv4.ip_forward       # = 1 であること
```

### worker が join できない

join コマンドのトークンには有効期限（24時間）がある。
`workers.yml` を再実行すると新しいトークンが自動生成される。

### Calico の Pod が起動しない

`k8s_pod_network_cidr`（デフォルト: `192.168.0.0/16`）が既存のネットワーク帯域と競合していないか確認する。
競合する場合は `ansible/inventory/group_vars/all.yml` の値を変更して `kubeadm reset` から再実行する。
