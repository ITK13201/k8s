## 1. op 参照・非秘密デフォルト・バックエンド設定の準備

- [x] 1.1 `terraform/proxmox/env.op` を作成し、秘密値（`TF_VAR_proxmox_password`）・個人情報（`TF_VAR_proxmox_endpoint`・`TF_VAR_control_plane_ip`・`TF_VAR_worker_ips`・`TF_VAR_gateway_ip`・`TF_VAR_worker_hdd_storage_by_id`・`TF_VAR_worker_hdd_backup_by_id`）・R2（`AWS_ACCESS_KEY_ID`・`AWS_SECRET_ACCESS_KEY`・`AWS_ENDPOINT_URL_S3`）を `op://K8s/<item>/<field>` 参照で記述する（配列は JSON 文字列）。実値が含まれないことを `grep -vE 'op://|^#|^$' terraform/proxmox/env.op` が空になることで確認する。
- [x] 1.2 `terraform/cloudflare/env.op` を作成し、秘密値（`TF_VAR_cloudflare_dns_api_token`・`TF_VAR_cloudflare_r2_api_token`）・個人情報（`TF_VAR_cloudflare_account_id`・`TF_VAR_home_ip`・さくらメール関連）・R2（`AWS_*`・`AWS_ENDPOINT_URL_S3`）を `op://K8s/<item>/<field>` 参照で記述する。同様に実値がないことを確認する。
- [x] 1.3 `terraform/proxmox/defaults.auto.tfvars`・`terraform/cloudflare/defaults.auto.tfvars`（committed）を作成し、非秘密・非個人のデフォルト（`*_cpu_cores`・`*_memory_mb`・`*_disk_gb`・`worker_count`・`proxmox_username`・`datastore_id`・公開 DNS 等）を記述する。`grep -IE 'password|token|secret|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' terraform/*/defaults.auto.tfvars` が秘密/個人情報にヒットしないことを確認する。
- [x] 1.4 `.gitignore` に `*.env` を追加し、`env.op` と `defaults.auto.tfvars` が追跡対象のままであることを `git check-ignore -v terraform/proxmox/env.op terraform/proxmox/defaults.auto.tfvars || echo committable` で確認する（無視されないこと）。
- [x] 1.5 `terraform/proxmox/backend.hcl.example`・`terraform/cloudflare/backend.hcl.example` を op 方式に合わせて更新（bucket/key/region/skip_* の非秘密のみ残し、access_key/secret_key/endpoint は env.op へ移行した旨を記載）。`terraform.tfvars.example` を「秘密/個人情報は env.op、非秘密は defaults.auto.tfvars」へ誘導する内容に更新する。差分をレビューして秘密/個人情報のプレースホルダが残っていないことを確認する。
- [x] 1.6 `op whoami` でサインインを確認後、vault `K8s` に design D9 の 3 アイテム（`terraform-proxmox`・`terraform-cloudflare`・`cloudflare-r2`）を**空フィールドの器**として `op item create --category "Secure Note" --vault K8s` で作成する（既存アイテムは上書きせず不足フィールドのみ追加）。秘密系フィールドは concealed 型とする。`op item get <item> --vault K8s --fields label=<field>` で各フィールドが存在し値が空であることを確認する（値の投入はユーザーが手動で行うため空のまま残す）。実行前にレイアウトをユーザーへ提示し了承を得る。

## 2. Makefile の骨組みと preflight

- [x] 2.1 ルートに `Makefile` を作成し、`.PHONY`・`help`（`##` コメントによる self-documenting 一覧）・デフォルトゴール `help` を実装する。`make` および `make help` がターゲット一覧を表示することを確認する。
- [x] 2.2 内部ターゲット `_require-op` を実装し、`command -v op` と `op whoami` を検査して失敗時は明確なメッセージで非ゼロ終了させる。Claude 側は `PATH= make _require-op`（op 不在を模擬）が非ゼロ終了しメッセージが出ることを確認する。未サインイン時の挙動確認はユーザーが行う。
- [x] 2.3 workspace/接続先 IP などを Makefile 変数（`?=` で上書き可能）として定義し、bucket/key/region を `-backend-config` フラグ定数として定義する。`make -n tf-proxmox-init` で意図した `-backend-config` フラグが展開されることを確認する。

## 3. Terraform ターゲット

- [x] 3.1 `tf-proxmox-init` を実装（`_require-op` 前提、`op run --env-file=terraform/proxmox/env.op -- terraform -chdir=terraform/proxmox init -backend-config=...`）。`make -n tf-proxmox-init` が `op run --env-file` 経由の呼び出しになっていることを確認する。
- [x] 3.2 `tf-proxmox-{plan,apply,destroy,output}` を実装する。Claude 側は `make -n tf-proxmox-plan` で `op run --env-file=terraform/proxmox/env.op -- terraform -chdir=... plan` に展開されることを確認する。**（ユーザー実行）** op に値を投入後 `make tf-proxmox-plan` を実行し、完了後 `env | grep -E 'TF_VAR_proxmox_password|AWS_SECRET'` が空（親シェルに残らない）であることを確認する。
- [x] 3.3 `tf-cloudflare-{init,plan,apply,destroy,output}` を同方式で実装する。Claude 側は `make -n tf-cloudflare-plan` が `op run --env-file=terraform/cloudflare/env.op` 経由になることを確認する。実値での実行確認はユーザーが行う。
- [x] 3.4 **（ユーザー実行）** 値投入後、インストール済み Terraform が `AWS_ENDPOINT_URL_S3` を honor するか `make tf-proxmox-init` で疎通確認する。未対応の場合は design D3/Risks のフォールバック（`init` に限り `op inject` で一時 backend.hcl を描画→init→即削除）を該当ターゲットに実装し、init が R2 バックエンドへ接続成功することを確認する。

## 4. Ansible / SSH / kubectl ターゲット

- [x] 4.1 `ansible-{ping,site,control-plane,workers,argocd}` を実装（inventory を明示、SSH は 1Password SSH Agent 経由）。Claude 側は `make -n ansible-ping` でコマンド展開を確認する。**（ユーザー実行）** `make ansible-ping` が全ホストへ疎通することを確認する。
- [x] 4.2 `ansible-secret`（`op inject -i .../secret.yml.tpl -o .../secret.yml`）を実装する。Claude 側は `make -n ansible-secret` でコマンド展開を確認する。**（ユーザー実行）** `make ansible-secret` 実行後に `secret.yml` が生成され gitignored のままであることを確認する（op inject は秘密値を解決するためユーザーが実行）。
- [x] 4.3 `ssh-cp` / `ssh-worker` を実装し、既存 `~/.ssh/config`（1Password SSH Agent）経由で接続する。接続先ホストは個人情報のため `op read`（または `CP_HOST ?=` 変数、`make ssh-cp CP_HOST=...` で上書き可能）で解決し Makefile にハードコードしない。Claude 側は `make -n ssh-cp` で展開を確認する。**（ユーザー実行）** `make ssh-cp` で control-plane にログインできることを確認する（秘密鍵ファイル未使用）。
- [x] 4.4 `kubeconfig`（SSH Agent 経由の scp で取得）と `k-nodes` / `k-pods` 等の確認系ターゲットを実装する。Claude 側は `make -n` で展開を確認する。**（ユーザー実行）** `make k-nodes` が既存 kubeconfig でノード一覧を返すことを確認する。

## 5. 移行とドキュメント

- [x] 5.1 **（ユーザー実行）** op アイテムの各フィールドに値を投入し、ローカルの `terraform/{proxmox,cloudflare}/terraform.tfvars` と `backend.hcl` を削除する（秘密/個人情報は env.op、非秘密は defaults.auto.tfvars へ移設済み）。削除後に `make tf-proxmox-plan` / `make tf-cloudflare-plan` の差分がゼロ（リソース変更なし）であることを確認する。
- [x] 5.2 `docs/terraform.md` を Makefile ベースの手順（`make tf-*`・env.op・op 前提）に更新する。記載コマンドと Makefile ターゲットが一致することを確認する。
- [x] 5.3 `docs/ansible.md` を Makefile ベース（`make ansible-*`・`make ssh-*`・`make kubeconfig`）に更新する。記載コマンドと Makefile ターゲットが一致することを確認する。
- [x] 5.4 `openspec validate add-makefile-op-commands --strict` を実行し、変更のスペックが検証を通過することを確認する。
