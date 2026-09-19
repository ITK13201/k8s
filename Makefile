# Makefile — 運用コマンド集約（Terraform / Ansible / SSH / kubectl）
#
# 秘密値・個人情報は 1Password から実行時にのみ子プロセスへ注入する（`op run --env-file`）。
# 親シェルの環境やディスクには残さない。値の投入は 1Password 上でユーザーが手動で行う。
#
# 使い方: `make`（または `make help`）でターゲット一覧を表示する。

.DEFAULT_GOAL := help

# ---- 変数（?= は環境や `make VAR=...` で上書き可能） ----

# Terraform ワークスペース
TF_PROXMOX_DIR    ?= terraform/proxmox
TF_CLOUDFLARE_DIR ?= terraform/cloudflare
TF_PROXMOX_ENV    ?= $(TF_PROXMOX_DIR)/env.op
TF_CLOUDFLARE_ENV ?= $(TF_CLOUDFLARE_DIR)/env.op

# Cloudflare R2 バックエンド（非秘密のみ。認証情報と endpoint は env.op の AWS_* で供給）
TF_BACKEND_BUCKET         ?= tf-state-k8s
TF_BACKEND_REGION         ?= auto
TF_PROXMOX_BACKEND_KEY    ?= proxmox/terraform.tfstate
TF_CLOUDFLARE_BACKEND_KEY ?= cloudflare/terraform.tfstate

# 非秘密バックエンド設定フラグ（bucket/region/skip_*/use_path_style は個別に key を付与）
TF_BACKEND_COMMON_FLAGS := \
	-backend-config=bucket=$(TF_BACKEND_BUCKET) \
	-backend-config=region=$(TF_BACKEND_REGION) \
	-backend-config=skip_credentials_validation=true \
	-backend-config=skip_metadata_api_check=true \
	-backend-config=skip_region_validation=true \
	-backend-config=skip_requesting_account_id=true \
	-backend-config=use_path_style=true

# Ansible（ansible.cfg の相対パス設定のため ansible/ ディレクトリ内で実行する）
ANSIBLE_DIR ?= ansible

# SSH 接続先（個人情報の IP はハードコードせず ~/.ssh/config の Host エイリアスを既定にする。
# 上書き例: `make ssh-cp CP_HOST=192.168.1.200`）
CP_HOST         ?= k8s-cp01
WORKER_HOST     ?= k8s-worker01
KUBECONFIG_DEST ?= $(HOME)/.kube/config

.PHONY: help _require-op \
	tf-proxmox-init tf-proxmox-plan tf-proxmox-apply tf-proxmox-destroy tf-proxmox-output \
	tf-cloudflare-init tf-cloudflare-plan tf-cloudflare-apply tf-cloudflare-destroy tf-cloudflare-output \
	ansible-ping ansible-site ansible-control-plane ansible-workers ansible-argocd ansible-secret \
	ssh-cp ssh-worker kubeconfig k-nodes k-pods

# ============================================================
# ヘルプ
# ============================================================

help: ## このターゲット一覧を表示する
	@echo "使用可能なターゲット:"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z0-9_-]+:.*##/ {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ============================================================
# preflight（1Password 前提条件チェック）
# ============================================================

# op 依存ターゲットの prerequisite。未インストール/未サインイン時は明確なメッセージで非ゼロ終了する。
_require-op:
	@command -v op >/dev/null 2>&1 || { echo "エラー: 1Password CLI (op) が見つかりません。インストールしてください。" >&2; exit 1; }
	@op whoami >/dev/null 2>&1 || { echo "エラー: 1Password にサインインしていません。'op signin' でサインインしてください。" >&2; exit 1; }

# ============================================================
# Terraform: Proxmox（秘密値/個人情報は op run --env-file で注入）
# ============================================================

tf-proxmox-init: _require-op ## Proxmox: terraform init（R2 バックエンド）
	op run --env-file=$(TF_PROXMOX_ENV) -- terraform -chdir=$(TF_PROXMOX_DIR) init -reconfigure \
		$(TF_BACKEND_COMMON_FLAGS) -backend-config=key=$(TF_PROXMOX_BACKEND_KEY)

tf-proxmox-plan: _require-op ## Proxmox: terraform plan
	op run --env-file=$(TF_PROXMOX_ENV) -- terraform -chdir=$(TF_PROXMOX_DIR) plan

tf-proxmox-apply: _require-op ## Proxmox: terraform apply
	op run --env-file=$(TF_PROXMOX_ENV) -- terraform -chdir=$(TF_PROXMOX_DIR) apply

tf-proxmox-destroy: _require-op ## Proxmox: terraform destroy
	op run --env-file=$(TF_PROXMOX_ENV) -- terraform -chdir=$(TF_PROXMOX_DIR) destroy

tf-proxmox-output: _require-op ## Proxmox: terraform output -json（VM の IP 等）
	op run --env-file=$(TF_PROXMOX_ENV) -- terraform -chdir=$(TF_PROXMOX_DIR) output -json

# ============================================================
# Terraform: Cloudflare
# ============================================================

tf-cloudflare-init: _require-op ## Cloudflare: terraform init（R2 バックエンド）
	op run --env-file=$(TF_CLOUDFLARE_ENV) -- terraform -chdir=$(TF_CLOUDFLARE_DIR) init -reconfigure \
		$(TF_BACKEND_COMMON_FLAGS) -backend-config=key=$(TF_CLOUDFLARE_BACKEND_KEY)

tf-cloudflare-plan: _require-op ## Cloudflare: terraform plan
	op run --env-file=$(TF_CLOUDFLARE_ENV) -- terraform -chdir=$(TF_CLOUDFLARE_DIR) plan

tf-cloudflare-apply: _require-op ## Cloudflare: terraform apply
	op run --env-file=$(TF_CLOUDFLARE_ENV) -- terraform -chdir=$(TF_CLOUDFLARE_DIR) apply

tf-cloudflare-destroy: _require-op ## Cloudflare: terraform destroy
	op run --env-file=$(TF_CLOUDFLARE_ENV) -- terraform -chdir=$(TF_CLOUDFLARE_DIR) destroy

tf-cloudflare-output: _require-op ## Cloudflare: terraform output -json
	op run --env-file=$(TF_CLOUDFLARE_ENV) -- terraform -chdir=$(TF_CLOUDFLARE_DIR) output -json

# ============================================================
# Ansible（ansible/ 内で実行。SSH は 1Password SSH Agent 経由）
# ============================================================

ansible-ping: ## Ansible: 全ホストへ疎通確認（ping）
	cd $(ANSIBLE_DIR) && ansible all -m ping

ansible-site: ## Ansible: 全ノードへ site.yml を適用
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/site.yml

ansible-control-plane: ## Ansible: control plane へ control_plane.yml を適用
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/control_plane.yml

ansible-workers: ## Ansible: ワーカーへ workers.yml を適用
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/workers.yml

ansible-argocd: ## Ansible: ArgoCD を argocd.yml で適用
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/argocd.yml

ansible-secret: _require-op ## Ansible: op inject で workers/secret.yml を生成（gitignored）
	cd $(ANSIBLE_DIR) && op inject -i inventory/group_vars/workers/secret.yml.tpl \
		-o inventory/group_vars/workers/secret.yml

# ============================================================
# SSH（1Password SSH Agent 経由。秘密鍵ファイルは使用しない）
# ============================================================

ssh-cp: ## SSH: control plane にログイン（CP_HOST で上書き可）
	ssh $(CP_HOST)

ssh-worker: ## SSH: ワーカーにログイン（WORKER_HOST で上書き可）
	ssh $(WORKER_HOST)

kubeconfig: ## kubeconfig を control plane から取得（SSH Agent 経由）
	ssh $(CP_HOST) sudo cat /root/.kube/config > $(KUBECONFIG_DEST)
	@echo "kubeconfig を $(KUBECONFIG_DEST) に取得しました。"

# ============================================================
# kubectl（既存 kubeconfig を用いた確認系）
# ============================================================

k-nodes: ## kubectl: ノード一覧を表示
	kubectl get nodes -o wide

k-pods: ## kubectl: 全 namespace の Pod を表示
	kubectl get pods -A
