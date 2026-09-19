## Purpose

リポジトリの運用コマンド（Terraform・Ansible・SSH・kubectl）をルートの Makefile に集約し、秘密値をすべて 1Password から実行時に取得して親シェルやディスクへ永続化せずに扱う能力。

## ADDED Requirements

### Requirement: ルート Makefile が運用コマンドを提供すること

リポジトリルートに `Makefile` が存在し、Terraform・Ansible・SSH・kubectl の主要な運用操作を名前付きターゲットとして提供しなければならない（SHALL）。
各ターゲットは冪等な命名規則（例: `tf-proxmox-plan`, `tf-cloudflare-apply`, `ansible-site`, `ssh-cp`, `k-nodes`）に従い、`make help` で一覧と説明を表示できること。

#### Scenario: ターゲット一覧を表示する

- **WHEN** リポジトリルートで `make help`（または引数なしの `make`）を実行する
- **THEN** 提供されるターゲット名と各ターゲットの説明が一覧表示される

#### Scenario: Terraform 操作をターゲット経由で実行する

- **WHEN** `make tf-proxmox-plan` を実行する
- **THEN** `terraform -chdir=terraform/proxmox plan` 相当の処理が実行される

### Requirement: 秘密値・個人情報を 1Password から実行時にのみ取得すること

Terraform の秘密値（proxmox パスワード・Cloudflare API トークン・R2 の access key / secret key）および個人情報（VM の IP アドレス・Cloudflare `account_id`・`home_ip`・storage by-id・R2 エンドポイント等）は、Makefile ターゲット実行時に `op`（1Password CLI）経由で取得し、コマンドを実行する子プロセスにのみ供給しなければならない（SHALL）。
これらの値を親シェルの環境変数として `export` してはならず（SHALL NOT）、実値を平文としてリポジトリ配下のファイルに書き出してはならない（SHALL NOT）。

#### Scenario: 秘密値・個人情報が子プロセスにのみ注入される

- **WHEN** `make tf-proxmox-apply` を実行する
- **THEN** 秘密値・個人情報は `op run --env-file` により子プロセスの環境変数として一時的に注入され、コマンド終了後に親シェルの環境には残らない

#### Scenario: 実値がリポジトリに存在しない

- **WHEN** リポジトリ内を検索する
- **THEN** proxmox パスワード・Cloudflare トークン・R2 キー・IP アドレス・`account_id` 等の実値を含むファイルは存在せず、これらの参照はすべて `op://` 参照として表現されている

#### Scenario: 非秘密・非個人のデフォルトはコミットされる

- **WHEN** CPU/メモリ/ディスクサイズや `proxmox_username`・`datastore_id` 等の非秘密・非個人の設定を確認する
- **THEN** それらは committed の `*.auto.tfvars` にバージョン管理され、`op://` 参照や gitignored ファイルには含まれない

### Requirement: op 参照ファイルはコミット可能で実体は gitignore されること

Terraform に秘密値を供給する env ファイルは `op://` 参照のみを含み、実値を含まないためコミット可能でなければならない（SHALL）。当該ファイルは `.env` で終わらない命名（`env.op`）とする。
実体化された（実値を含みうる）`.env` ファイルは誤コミットを防ぐため `.gitignore` により除外されなければならない（SHALL）。

#### Scenario: op 参照ファイルがコミット対象になる

- **WHEN** `env.op` ファイルの内容を確認する
- **THEN** すべての値が `op://<vault>/<item>/<field>` 形式の参照であり、実値は含まれない

#### Scenario: 実体化された env ファイルが除外される

- **WHEN** リポジトリ配下に `*.env` ファイルが作成される
- **THEN** `.gitignore` により Git の追跡対象から除外される

### Requirement: op / 前提条件の欠如時に明確に失敗すること

Makefile ターゲットは `op` が未インストールまたは未サインインの場合、秘密値なしで Terraform を実行して不完全・危険な操作に進むのではなく、明確なエラーメッセージとともに失敗しなければならない（SHALL）。

#### Scenario: op 未サインインで実行する

- **WHEN** 1Password にサインインしていない状態で `make tf-proxmox-apply` を実行する
- **THEN** ターゲットは非ゼロで終了し、`op` のサインインが必要である旨のメッセージが表示される

### Requirement: SSH / kubectl 操作を既存の 1Password 連携で提供すること

SSH 接続系ターゲットは既存の 1Password SSH Agent（`~/.1password/agent.sock`）を用い、秘密鍵をファイルとして扱わずに認証しなければならない（SHALL）。
kubectl 系ターゲットは既存の kubeconfig を用いてクラスタ確認操作を提供すること。

#### Scenario: SSH Agent 経由で control-plane に接続する

- **WHEN** `make ssh-cp` を実行する
- **THEN** 1Password SSH Agent 経由で control-plane VM に SSH 接続する（秘密鍵ファイルは使用しない）

#### Scenario: kubectl でノード状態を確認する

- **WHEN** `make k-nodes` を実行する
- **THEN** 既存の kubeconfig を用いて `kubectl get nodes` 相当の結果が表示される
