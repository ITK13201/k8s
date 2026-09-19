## Context

動機とスコープは proposal.md（Why / What Changes）を参照。

現状の制約:

- Terraform は S3 互換バックエンド（Cloudflare R2）を使用する（`backend "s3" {}` を空宣言し `-backend-config` で値を注入）。R2 の access/secret key とエンドポイント（`ACCOUNT_ID.r2.cloudflarestorage.com`）は現在 gitignored な `backend.hcl` に平文で保存されている。
- Terraform 変数の秘密値は `terraform.tfvars`（gitignored）にある: proxmox は `proxmox_password`、cloudflare は `cloudflare_dns_api_token` / `cloudflare_r2_api_token`。
- Ansible の SSH は既に 1Password SSH Agent（`~/.1password/agent.sock`）経由。`workers/secret.yml` は `op inject` で生成する既存フローがある。
- proxmox provider の SSH は 1Password SSH Agent（`~/.1password/agent.sock`）経由に移行した（`ssh { agent = true; agent_socket = pathexpand("~/.1password/agent.sock") }`）。秘密鍵ファイル（`file(...)`）は扱わない。公開鍵（`ssh_public_key`）は cloud-init で VM に注入するため引き続き必要。
- 1Password アイテムの作成・読み取り検証はユーザーが手動で行う方針（本設計では op 参照の *形* のみ定義し、実アイテムの存在は前提とする）。
- ルートに `Makefile` は未存在。開発ツールは `nix develop`（flake）で提供され、`op` は各自の環境に導入されている前提。

## Goals / Non-Goals

**Goals:**

- Terraform・Ansible・SSH・kubectl の運用コマンドをルート `Makefile` の名前付きターゲットに集約する。
- Terraform の秘密値・個人情報を `op run --env-file` により実行時のみ子プロセスへ注入し、親シェル・ディスクに残さない。
- 秘密値・個人情報の参照を `op://` 参照（vault `K8s`）のみのコミット可能な `env.op` に集約し、平文 `backend.hcl` と gitignored `terraform.tfvars` を廃止する。
- 非秘密・非個人のデフォルトを committed の `*.auto.tfvars` に移し、バージョン管理下で可視化する。

**Non-Goals:**

- （更新）当初は proxmox provider の SSH を現行のファイル方式（`file(var.proxmox_ssh_private_key_path)`）のまま維持する Non-Goal だったが、実装中にユーザー判断で 1Password SSH Agent（`agent = true`）へ移行した。これに伴い `proxmox_ssh_private_key_path` 変数と env.op 参照・op フィールドは廃止し、`ssh_public_key` のみ op 参照で残す。
- 1Password の vault 設計・権限設定・**フィールドへの値投入**（ユーザーが手動）。アイテム/フィールドの**雛形（空の器）作成**は本変更で行う（D9）。参照先 vault は既存の `K8s`。
- 非秘密・非個人のデフォルト（CPU/メモリ/ディスクサイズ・`worker_count`・`proxmox_username`・`datastore_id` 等）を 1Password 化すること。これらは committed の `*.auto.tfvars` に置く（D8）。
- ArgoCD / GitOps・クラスタ内アプリのデプロイフロー（無関係・不変）。

## Decisions

### D1: 秘密値の供給は `op run --env-file`（一時的な子プロセス env 注入）

`op run --env-file=<file> -- <command>` は `op://` 参照を解決し、コマンドを実行する子プロセスの環境変数としてのみ値を供給する。親シェルの環境やディスクには残らない。

- 代替案 A（`op inject` で tfvars/backend.hcl を一時描画→削除）: 環境変数を一切使わないが、実行中にディスク上へ平文が生成され、異常終了時の削除漏れリスクがある。ユーザーは env 方式を選好。→ 不採用（ただし backend 初期化のフォールバックとして限定利用の可能性を D3 で言及）。
- 代替案 B（`export $(op read ...)` で親シェルに設定）: 親シェルに秘密値が残るため要件「環境変数等に残さない」に反する。→ 不採用。

### D2: env ファイルは `env.op` 命名でコミット、`*.env` は gitignore

`env.op` は `op://K8s/<item>/<field>` 参照のみを含み実値を持たないためコミット可能（vault は既存の `K8s` を使用）。ユーザー要望により `.env` 拡張子は避ける（`*.env` は将来的に gitignore したいため）。安全策として `.gitignore` に `*.env` を追加し、万一実体化された env が誤コミットされないようにする。

配置: `terraform/proxmox/env.op`、`terraform/cloudflare/env.op`（各ワークスペース単位）。

### D3: R2 バックエンドの認証情報を env で供給、bucket/key は Makefile の `-backend-config` フラグ

S3 互換バックエンドは AWS SDK 標準の環境変数を読む:

- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` ← R2 の API キー（op 参照）
- `AWS_ENDPOINT_URL_S3` ← R2 エンドポイント（`ACCOUNT_ID` を含むため個人情報。op 参照で供給）

非秘密の `bucket` / `key` / `region` / `skip_*` フラグは Makefile 内の `-backend-config=key=value` フラグとして明示する（バージョン管理され可読）。これにより平文 `backend.hcl` を完全に廃止できる。

- リスク補足: インストール済み Terraform の S3 バックェンドが `AWS_ENDPOINT_URL_S3` を honor しない版だった場合のフォールバックは Risks 参照。

### D4: TF 変数の秘密値・個人情報は `TF_VAR_*` env で供給

- proxmox: `TF_VAR_proxmox_password`（秘密）、`TF_VAR_proxmox_endpoint`・`TF_VAR_control_plane_ip`・`TF_VAR_worker_ips`・`TF_VAR_gateway_ip`・`TF_VAR_worker_hdd_storage_by_id`・`TF_VAR_worker_hdd_backup_by_id`（個人情報）← op 参照
- cloudflare: `TF_VAR_cloudflare_dns_api_token`・`TF_VAR_cloudflare_r2_api_token`（秘密）、`TF_VAR_cloudflare_account_id`・`TF_VAR_home_ip`・さくらメール関連（個人情報）← op 参照

配列型（`worker_ips`・`dns_servers` 等）は `TF_VAR_name='["..."]'` の JSON 文字列で表現する。`terraform.tfvars`（gitignored）は廃止し、これらは env.op、非秘密デフォルトは D8 の `*.auto.tfvars` へ振り分ける。

### D8: 非秘密・非個人のデフォルトは committed `*.auto.tfvars`

秘密でも個人情報でもない値（`control_plane_cpu_cores`・`*_memory_mb`・`*_disk_gb`・`worker_count`・`proxmox_username="root@pam"`・`datastore_id`・`dns_servers` の公開 DNS 部分等）は `terraform/<workspace>/defaults.auto.tfvars`（committed）に置く。`*.auto.tfvars` は `terraform` が自動読込するため Makefile 側の指定は不要。バージョン管理下で差分が追え、秘密/個人情報と明確に分離できる。

- 代替案（すべて env.op の TF_VAR_* に集約）: サイジング等まで op 参照/リテラルで env.op に並び、非秘密値まで 1Password 依存になり冗長。→ 不採用（ユーザー選好）。

### D9: 1Password アイテム/フィールドの雛形を本変更で作成する

`env.op` の `op://` 参照が解決できるよう、vault `K8s` に以下 3 アイテムを**空フィールドの器として** `op item create` で作成する。値の投入はユーザーが手動で行う（Claude は値を読み書きしない）。既存アイテムがある場合は上書きせず不足フィールドのみ追加する。

| アイテム | フィールド（型） | マップ先 env |
|---|---|---|
| `terraform-proxmox` | `password`(concealed), `endpoint`, `control_plane_ip`, `worker_ips`, `gateway_ip`, `worker_hdd_storage_by_id`, `worker_hdd_backup_by_id` | `TF_VAR_proxmox_password` ほか |
| `terraform-cloudflare` | `dns_api_token`(concealed), `r2_api_token`(concealed), `account_id`, `home_ip`, `sakura_mail_server`, `sakura_spf_txt`, `sakura_dmarc_rua` | `TF_VAR_cloudflare_*` ほか |
| `cloudflare-r2`（proxmox/cloudflare 両 backend で共有） | `access_key_id`(concealed), `secret_access_key`(concealed), `endpoint` | `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_ENDPOINT_URL_S3` |

`env.op` の参照パスは上表の `op://K8s/<item>/<field>` に一致させる。カテゴリは任意フィールドを持てる `Secure Note`（`op item create --category "Secure Note" --title <item> --vault K8s '<field>[<type>]='`）を用いる。`ssh_public_key`（cloud-init 用・個人に紐づくため op 参照）は `terraform-proxmox` アイテムに追加する。`proxmox_ssh_private_key_path` は SSH Agent 移行により廃止したため op アイテムには含めない。

- 注記: この操作は外部への副作用（1Password への書き込み）を伴うため apply フェーズで実行し、実行前にレイアウトをユーザーへ提示する。値投入・`op item get` での確認はユーザーが行う。

### D5: Makefile 前提条件チェック（preflight）

秘密値を欠いたまま `terraform apply` に進むと不完全・危険なため、op 依存ターゲットは実行前に `command -v op` と `op whoami` を確認し、失敗時は明確なメッセージで非ゼロ終了する。共通の内部ターゲット（例: `_require-op`）を prerequisite に置く。

### D6: SSH / kubectl ターゲットは既存連携をラップ

- SSH: `ssh-cp` / `ssh-worker` は既存の `~/.ssh/config`（`IdentityAgent ~/.1password/agent.sock`）を利用し秘密鍵ファイルを扱わない。接続先 IP は個人情報のため Makefile にハードコードせず、`op read` で取得するか Makefile 変数（`CP_HOST ?= $(shell op read op://K8s/...)` 等、`make ssh-cp CP_HOST=...` で上書き可能）で解決する。
- kubeconfig 取得: `kubeconfig` ターゲットは 1Password SSH Agent 経由の `scp` で control-plane から取得する。
- kubectl: `k-nodes` / `k-pods` 等は既存 kubeconfig を用いた確認系のみ提供する（秘密値注入は不要）。

### D7: ターゲット命名規則

`<tool>-<workspace>-<action>` を基本とする: `tf-proxmox-{init,plan,apply,destroy,output}`、`tf-cloudflare-{...}`、`ansible-{ping,site,control-plane,workers,argocd,secret}`、`ssh-{cp,worker}`、`k-{nodes,pods,...}`、`kubeconfig`、`help`。`.PHONY` を全ターゲットに付与し、`make` 単独実行で `help` を表示する（self-documenting `##` コメント方式）。

## Risks / Trade-offs

- [S3 バックエンドが `AWS_ENDPOINT_URL_S3` を未対応] → 実装時にインストール版で疎通確認する。未対応なら、backend 初期化（`terraform init`）に限り `op inject` で一時 `backend.hcl` を描画→`init`→即削除する D1 代替案 A のフォールバックを採用（plan/apply は env 方式を維持）。
- [子プロセス env はプロセス一覧やコアダンプに露出しうる] → `op run` の一時性で永続化は防げるが、実行中の露出は env 方式の本質的トレードオフ。ユーザー選好により許容。CLI 引数へ秘密を渡す方式（`ps` で全ユーザーに露出）よりは安全。
- [tfvars 廃止に伴う移行漏れ（秘密/個人情報が env.op へ、非秘密が auto.tfvars へ正しく振り分けられない）] → 移行手順で「ローカル tfvars を削除後も `plan` の差分がゼロ」であることを検証するタスクを設ける。既存のローカル tfvars はユーザー環境にのみ存在するため、ドキュメントで手動削除を案内する。
- [op アイテムのフィールドパス不一致] → `env.op` の `op://` 参照パスは想定命名で記述し、実アイテムはユーザーが用意する前提。`op run` は解決失敗時に明確なエラーを返すため、preflight とは別に実行時検知される。
- [`make` 実行時に `op` が biometric 再認証を要求] → 対話が挟まる場合があるが、非対話 CI 用途は本リポジトリの想定外（個人運用）。許容。

## Migration Plan

1. `Makefile`・`env.op`（各ワークスペース）・`defaults.auto.tfvars`（非秘密デフォルト）・`.gitignore` 更新・`*.example` 更新を追加する。
2. ユーザーが `K8s` vault に必要アイテム（proxmox password/endpoint・cloudflare トークン/account_id・R2 キー/エンドポイント・各種 IP・storage by-id 等）を用意する（手動）。
3. ユーザーがローカルの `terraform/*/terraform.tfvars` と `backend.hcl` を削除する（秘密/個人情報は env.op、非秘密デフォルトは `defaults.auto.tfvars`、backend 値はフラグ/env で供給されるため不要になる）。
4. `make tf-proxmox-init` → `plan` で疎通確認。差分が既存 state と一致すること（秘密値供給経路が変わるだけでリソース差分は出ない）を確認する。
5. `docs/terraform.md` / `docs/ansible.md` を Makefile 手順へ更新する。

ロールバック: `Makefile` 系は追加物であり、従来どおり `backend.hcl` + `terraform.tfvars`（秘密/個人情報含む）を復元すれば元のフローに戻せる（破壊的変更はローカルファイルの扱いのみ）。
