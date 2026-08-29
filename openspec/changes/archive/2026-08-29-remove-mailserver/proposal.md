## Why

mailserver（docker-mailserver on Kubernetes）は廃止となったため、関連するすべてのリソース・設定・ドキュメントを削除し、リポジトリを整理する。

## What Changes

- `manifests/mailserver/` ディレクトリ全体を削除（Kustomize + Helm chart + ExternalSecret + Certificate 等）
- `manifests/namespaces/mailserver.yaml` を削除し、kustomization.yaml から参照を除去
- `manifests/pv/mailserver-{data,state,config,log}.yaml` の4ファイルを削除し、kustomization.yaml から参照を除去
- `docs/design/mailserver.md` を削除
- `CLAUDE.md` の mailserver.md へのリンクを除去
- `docs/applications.md` の mailserver アプリ行を削除
- `docs/secrets.md` の mailserver シークレット関連記述を削除
- `ansible/inventory/group_vars/workers/main.yml` の mailserver PV ディレクトリ定義を削除
- `terraform/cloudflare/dns_mail.tf` を削除（A/MX/SPF/DMARC/Resend DKIM・Return-Path すべての DNS レコード）
- `terraform/cloudflare/variables.tf` から `resend_dkim_txt` 変数定義を削除
- `terraform/cloudflare/terraform.tfvars` から `resend_dkim_txt` の値を削除
- `terraform/cloudflare/terraform.tfvars.example` からコメントアウトされた `resend_dkim_txt` 行を削除
- `docs/design/terraform-cloudflare.md` の mail/MX/SPF/DMARC/Resend DNS セクションおよび `resend_dkim_txt` の記述を削除
- `docs/design/secrets-1password.md` の mailserver 関連記述を削除
- ホスト上の実データ（`/mnt/hdd/data/k8s/pv/mailserver/`）を手動 SSH で削除
- 1Password vault の `mailserver-resend-secret` アイテムを手動削除

## Capabilities

### New Capabilities
（なし）

### Modified Capabilities
（なし — 純粋なリソース削除。skip_specs: true を使用）

## Impact

- **ArgoCD**: `manifests/mailserver/` を削除することで ApplicationSet の自動検出から外れ、prune により `k8s-mailserver` Application とそのリソースがクラスタから削除される
- **PersistentVolume**: mailserver 用 PV 4本（data/state/config/log）が削除される。クラスタ上のデータ（`/mnt/hdd/data/k8s/pv/mailserver/`）は Ansible の変数からも除去される（ただし実ファイルシステムは手動削除が必要）
- **Namespace**: `mailserver` namespace が削除される
- **Secrets (1Password)**: `manifests/mailserver/external-secret.yaml` 削除により ESO が mailserver-resend-secret を同期しなくなる
- **Certificate**: `manifests/mailserver/certificate.yaml` 削除により cert-manager が mail 用 TLS 証明書を発行・更新しなくなる
- **ドキュメント**: 設計書 `docs/design/mailserver.md` および CLAUDE.md/applications.md/secrets.md 内の参照が消える
- **Cloudflare DNS**: `terraform/cloudflare/dns_mail.tf` 削除・変数整理後に `terraform apply`（手動実行）で、`mail.i-tk.dev` A レコード・MX・SPF・DMARC・Resend DKIM/Return-Path レコードがすべて削除される
- **ホストデータ**: k8s-worker01 上の `/mnt/hdd/data/k8s/pv/mailserver/` を手動 SSH で削除する
- **1Password**: `mailserver-resend-secret` vault アイテムを手動削除する
