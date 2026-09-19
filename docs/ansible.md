# Ansible 手順（k8s インストール）

設計の詳細は [docs/design/ansible.md](design/ansible.md) を参照すること。

## 前提条件

- Terraform で VM が起動済みであること（[docs/terraform.md](terraform.md) を参照）
- 実行マシンに Ansible がインストール済みであること
- `ansible/inventory/hosts.yml` の IP アドレスが Terraform output と一致していること
- 1Password SSH Agent が設定済みで k8s 用 SSH 鍵が登録されていること（後述）

## 1Password SSH Agent のセットアップ

SSH 秘密鍵はファイルではなく 1Password SSH Agent 経由で提供する。

**初回セットアップ（鍵の作成）**

1. 1Password アプリで `新規アイテム > SSH キー > 鍵を生成` → 名前を `k8s-pve` として保存
2. 生成された公開鍵を各 VM の `~/.ssh/authorized_keys` に登録する（初回は Proxmox コンソールまたはパスワード認証で作業）

```bash
# 1Password SSH Agent が k8s 鍵を提供しているか確認
SSH_AUTH_SOCK=~/.1password/agent.sock ssh-add -L
```

`~/.ssh/config` では以下が設定済み（全ホスト共通）:

```
Host *
  IdentityAgent ~/.1password/agent.sock
```

## セットアップ

運用コマンドはリポジトリルートの `Makefile` 経由で実行する（`make help` で一覧表示）。
Ansible ターゲットは `ansible/` ディレクトリ内で実行される（`ansible.cfg` の相対パス設定のため）。

```bash
# Ansible Galaxy コレクションをインストール
ansible-galaxy collection install -r ansible/requirements.yml

# 接続確認（1Password SSH Agent 経由で認証される）
make ansible-ping
```

## k8s クラスタの構築

```bash
# コントロールプレーン＋ワーカーを一括セットアップ
make ansible-site

# コントロールプレーンのみ
make ansible-control-plane

# ワーカーのみ（コントロールプレーン構築済みの場合）
make ansible-workers
```

## クラスタの確認

```bash
# コントロールプレーンに SSH（1Password SSH Agent 経由・秘密鍵ファイル未使用）
make ssh-cp

# 手元から直接ノード状態を確認（既存 kubeconfig を使用）
make k-nodes
```

正常時の出力例:
```
NAME          STATUS   ROLES           AGE   VERSION
k8s-cp01      Ready    control-plane   5m    v1.32.x
k8s-worker01  Ready    <none>          3m    v1.32.x
```

## kubeconfig の取得

`site.yml` 完了後、手元のマシンで kubectl を使えるようにするため kubeconfig を取得する
（1Password SSH Agent 経由で control plane から取得。接続先は `CP_HOST` で上書き可能）。

```bash
make kubeconfig
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

## シークレットの生成（workers.secret.yml）

`ansible/inventory/group_vars/workers/secret.yml` は gitignore 対象のため、1Password CLI で生成する。
`make ansible-secret` は `op` サインインを前提とし（未サインイン時は明確なメッセージで失敗）、
テンプレートから `op inject` で生成する。

```bash
make ansible-secret
```

生成された `secret.yml` はローカルにのみ存在し、git に含まれない。
テンプレート（`secret.yml.tpl`）は git 管理対象。

## Dry-run（変更確認）

```bash
cd ansible && ansible-playbook playbooks/site.yml --check
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
