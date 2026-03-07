# ファイル・ドキュメント・スクリプト整理 設計書

## 背景

`feature/use-proxmox-ve` ブランチで Proxmox VE 移行に伴う大幅な変更を行った。
Terraform による VM プロビジョニング、Ansible による k8s クラスタ構築が導入され、
旧来の手動セットアップスクリプトや Vagrant ベースの開発環境が不要になった。

本設計書では、移行後に残っている不要ファイル・古いドキュメント・レガシースクリプトを
洗い出し、整理方針を定める。

## 対象範囲

以下の 4 カテゴリに分けて整理を行う。

1. **削除** — 完全に不要となったファイル
2. **更新** — 内容が古くなっているファイル
3. **統合** — 重複しているドキュメントの統合
4. **改善** — 動作はするが修正が望ましいスクリプト

---

## 1. 削除対象

### 1.1 `bin/create_k8s_cluster.sh`

- **理由**: kubeadm init を手動実行するスクリプト。Calico v3.28.1 がハードコードされている。
  Ansible ロール `k8s_control_plane` で完全に代替済み。
- **影響**: なし。Ansible playbook が同等の処理を行う。

### 1.2 `bin/install_k8s.sh`

- **理由**: containerd・kubelet・kubeadm・Helm を手動インストールするスクリプト。
  バージョン（containerd 1.7.22, k8s v1.31）がハードコードされている。
  Ansible ロール `containerd`, `k8s_node` で完全に代替済み。
- **影響**: なし。Ansible playbook が同等の処理を行う。

### 1.3 `Vagrantfile`

- **理由**: VirtualBox + CentOS 9 ベースの VM セットアップファイル。
  Proxmox VE 移行により不要。ローカル開発は Minikube で行う。
- **影響**: なし。Terraform + Proxmox VE が本番 VM を管理する。

### 1.4 `README_PRODUCTION.md`

- **理由**: タイトル（`# Kubernetes (Production)`）のみで内容が空。
  本番環境の手順は `docs/operations.md`・`docs/terraform.md`・`docs/ansible.md` に
  すべて記載済み。
- **影響**: `README.md` からのリンクを削除する必要がある。

---

## 2. 更新対象

### 2.1 `README.md`

現在の内容は `README_MINIKUBE.md` と `README_PRODUCTION.md` へのリンクのみで、
プロジェクト概要がない。さらにリンクにタイポがある（`README_MINIKUBEL.md`）。

**更新方針**:

- プロジェクト概要（Proxmox VE + ArgoCD + Kustomize + Helm による個人 k8s インフラ）を追加
- インフラ構成の簡易図（VM スペック含む）を追加
- ドキュメントへのリンク集を整理（`docs/` 配下への誘導）
- `README_PRODUCTION.md` へのリンクを削除
- `README_MINIKUBE.md` へのリンクのタイポを修正、もしくは `docs/local-dev.md` に誘導

### 2.2 `docs/architecture.md`

コンテンツは正確だが、`bin/` ディレクトリの説明が古い。

**更新方針**:

- ディレクトリ構成の説明で `bin/` の記述を実態に合わせる
  - 旧: 「クラスタセットアップ・運用スクリプト」
  - 新: 「シークレット生成・バックアップ・運用スクリプト」（セットアップは Ansible に移行）
- `terraform/` と `ansible/` ディレクトリの説明を追加

---

## 3. 統合対象

### 3.1 `README_MINIKUBE.md` → `docs/local-dev.md`

両ファイルの内容がほぼ重複している。

| 項目 | `README_MINIKUBE.md` | `docs/local-dev.md` |
|------|---------------------|---------------------|
| クラスタ起動 | ✅ | ✅ |
| クラスタ削除 | ✅ | ✅ |
| tunnel | ✅ | ✅ |
| addons | ✅ | ❌ |
| ローカルイメージ | ✅ | ✅ |
| プロファイル表示 | ✅ | ❌ |
| VM 内ディレクトリ | ❌ | ✅ |

**統合方針**:

- `README_MINIKUBE.md` にしかない情報（addons, プロファイル表示）を `docs/local-dev.md` に追記
- `README_MINIKUBE.md` を削除
- `README.md` からは `docs/local-dev.md` にリンクする

---

## 4. 改善対象

### 4.1 `bin/cronjobs/system/system_report.sh`

**問題**: `df -h | grep -e /dev/mapper/cs-root -e /dev/sd` が CentOS 固有のデバイスパスに
依存している。Rocky Linux 9（現在の OS）ではデバイス名が異なる可能性がある。

**改善方針**:

- 特定のデバイスパスを grep するのではなく、マウントポイントベースでフィルタする
- 例: `df -h --output=source,size,used,avail,pcent,target | grep -E '^/dev/'`
- もしくは対象パスを変数で定義して環境差異を吸収する

### 4.2 `bin/update/update-growi.sh`

**問題**: 4 つの PV 名（`growi-elasticsearch-data-pv`, `growi-elasticsearch-master-pv`,
`growi-mongodb-pv`, `growi-uploads-pv`）がハードコードされている。
PV が追加・変更された場合にスクリプトの修正が必要。

**改善方針**:

- `manifests/pv/` 配下の Growi 関連 PV 定義から名前を動的に取得する
- 例: `kubectl get pv -l app=growi -o name` でラベルベースに取得、
  またはファイル名パターン `growi-*.yaml` から抽出

### 4.3 `etc/root.crontab`

**問題**: スクリプトパスが `/usr/local/src/k8s/k8s/bin/cronjobs/` にハードコードされている。

**改善方針**:

- 現状維持（サーバー側のデプロイパスは固定のため変更不要）
- ただし、パスの正当性をドキュメント（`docs/operations.md`）に明記する

---

## 5. 実施計画

以下の順序で実施する。影響範囲の小さいものから着手する。

### Phase 1: 不要ファイルの削除

| # | 対象 | 作業内容 |
|---|------|---------|
| 1 | `bin/create_k8s_cluster.sh` | ファイル削除 |
| 2 | `bin/install_k8s.sh` | ファイル削除 |
| 3 | `Vagrantfile` | ファイル削除 |
| 4 | `README_PRODUCTION.md` | ファイル削除 |

### Phase 2: ドキュメント統合・更新

| # | 対象 | 作業内容 |
|---|------|---------|
| 5 | `docs/local-dev.md` | `README_MINIKUBE.md` の追加情報を統合 |
| 6 | `README_MINIKUBE.md` | ファイル削除 |
| 7 | `README.md` | プロジェクト概要の追加・リンク整理 |
| 8 | `docs/architecture.md` | ディレクトリ構成の説明を更新 |

### Phase 3: スクリプト改善

| # | 対象 | 作業内容 |
|---|------|---------|
| 9 | `bin/cronjobs/system/system_report.sh` | デバイスパス grep をディストリ非依存に変更 |
| 10 | `bin/update/update-growi.sh` | PV 名のハードコードを動的取得に変更 |

---

## 6. 実施後の確認

- [ ] 削除したファイルへの参照が他のファイルに残っていないこと
- [ ] `README.md` のリンクがすべて有効であること
- [ ] `docs/operations.md` の記載がスクリプト改善後の内容と一致すること
- [ ] `docs/architecture.md` のディレクトリ構成が実態と一致すること
- [ ] cron ジョブのスクリプトが正常に動作すること（`bash -n` で構文チェック）
