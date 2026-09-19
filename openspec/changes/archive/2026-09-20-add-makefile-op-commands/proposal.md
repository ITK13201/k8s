## Why

Terraform・Ansible・SSH・kubectl の運用コマンドは現在 `docs/` に散在しており、`terraform -chdir=... apply` のような長いコマンドを手打ちする必要がある。さらに Terraform の秘密値（proxmox_password・cloudflare トークン・R2 の access/secret key）が gitignore された平文の `terraform.tfvars` / `backend.hcl` に保存されており、1Password 一元管理（ESO・SSH Agent は既に op 化済み）の方針と乖離している。運用コマンドを Makefile に集約し、秘密値をすべて 1Password から実行時取得することで、操作の一貫性と秘密値の非永続化を実現する。

## What Changes

- リポジトリルートに `Makefile` を新設し、Terraform・Ansible・SSH・kubectl の主要コマンドをターゲットとして提供する。
- Terraform の秘密値・個人情報を `op run --env-file` で実行時にのみ子プロセスへ注入する（`TF_VAR_*` / `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_ENDPOINT_URL_S3`）。親シェルやディスクには残さない。参照する 1Password vault は既存の `K8s` を用いる。
- **BREAKING**: `terraform/{proxmox,cloudflare}/backend.hcl` と gitignored な `terraform.tfvars` を廃止する。秘密値（proxmox_password・cloudflare トークン・R2 access/secret key）と個人情報（IP・`account_id`・`home_ip`・storage by-id 等）を 1Password `K8s` vault へ移設し、コミット可能な `op://` 参照ファイル（`env.op` 命名）に集約する。
- 秘密でも個人情報でもない非秘密デフォルト（CPU/メモリ/ディスクサイズ・`worker_count`・`proxmox_username`・`datastore_id` 等）は committed の `*.auto.tfvars` に移し、バージョン管理下で可視化する。
- `env.op` は `op://` 参照のみを含みコミット可能とする。安全策として `.gitignore` に `*.env` を追加し、実体化された `.env` が誤ってコミットされないようにする。
- `K8s` vault に `env.op` 参照に対応する 1Password アイテム/フィールドの**雛形（空の器）を作成**する（`terraform-proxmox`・`terraform-cloudflare`・`cloudflare-r2`）。値の投入はユーザーが手動で行う。
- SSH は既存の 1Password SSH Agent（`~/.1password/agent.sock`）経由の接続を Makefile ターゲット化する（control-plane / worker への接続、kubeconfig 取得）。
- kubectl は `~/.kube/config` を用いた確認系コマンドを Makefile ターゲット化する。
- 上記に合わせて `docs/terraform.md` / `docs/ansible.md` の手順を Makefile ベースへ更新する。

## Capabilities

### New Capabilities
- `tooling/command-makefile`: リポジトリの運用コマンド（Terraform・Ansible・SSH・kubectl）を Makefile に集約し、秘密値を 1Password から実行時取得して非永続で扱う能力。

### Modified Capabilities
<!-- 既存の spec に対する要件変更はなし（cloudflare/mail-dns・apps/gomi-no-hi は本変更の対象外）。 -->

## Impact

- **新規**: `Makefile`（ルート）、`terraform/proxmox/env.op`・`terraform/cloudflare/env.op`（`op://` 参照のみ・コミット可）、`terraform/{proxmox,cloudflare}/*.auto.tfvars`（非秘密デフォルト・コミット可）。
- **変更**: `.gitignore`（`*.env` 追加）、`docs/terraform.md`・`docs/ansible.md`（Makefile 手順へ更新）、`terraform/*/backend.hcl.example`・`terraform.tfvars.example`（op 参照方式へ更新）。
- **廃止**: `terraform/{proxmox,cloudflare}/backend.hcl` および gitignored な `terraform.tfvars`（ローカルのみ・秘密値/個人情報を `K8s` vault へ、非秘密デフォルトを `*.auto.tfvars` へ移設）。
- **前提**: `op`（1Password CLI）がインストール済みかつサインイン済みであること。`K8s` vault が存在すること（アイテム/フィールドの雛形は本変更で作成し、値の投入はユーザーが手動で行う）。
- **外部副作用**: 本変更は `K8s` vault へ 1Password アイテム/フィールドの雛形を書き込む（値は空）。
- **影響範囲**: 運用手順のみ。ArgoCD による GitOps 同期・クラスタ内アプリの動作には影響しない。
