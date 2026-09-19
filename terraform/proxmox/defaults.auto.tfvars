# 非秘密・非個人のデフォルト（committed）。
# `*.auto.tfvars` は terraform が自動読込するため Makefile 側の指定は不要。
# 秘密値・個人情報（認証情報 / エンドポイント / IP / by-id / ssh 鍵等）は env.op の op:// 参照で供給する。
# 注意: 個人情報（IP アドレス・ホスト名等）はここに書かないこと。

# Proxmox 接続（非個人）
proxmox_username = "root@pam"
proxmox_node     = "pve"

# ストレージ
datastore_id = "local-lvm"

# VM ユーザー
vm_user = "k8s"

# Control plane サイジング
control_plane_cpu_cores = 2
control_plane_memory_mb = 8192
control_plane_disk_gb   = 30

# Worker サイジング
worker_count     = 1
worker_cpu_cores = 8
worker_memory_mb = 32768
worker_disk_gb   = 150
