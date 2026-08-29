## Context

proposal.md の Why を参照。mailserver は廃止済みであり、以下のリソースがリポジトリに残存している:

- `manifests/mailserver/` — Kustomize + Helm chart（docker-mailserver v5.1.1）
- `manifests/namespaces/mailserver.yaml` — Namespace 定義
- `manifests/pv/mailserver-{data,state,config,log}.yaml` — 4本の PersistentVolume
- `docs/design/mailserver.md` — 設計ドキュメント
- `CLAUDE.md`, `docs/applications.md`, `docs/secrets.md` — 参照・一覧への記載
- `ansible/inventory/group_vars/workers/main.yml` — PV ディレクトリパス定義
- `terraform/cloudflare/dns_mail.tf` — A/MX/SPF/DMARC/Resend DKIM・Return-Path DNS レコード
- `terraform/cloudflare/variables.tf` — `resend_dkim_txt` 変数定義
- `terraform/cloudflare/terraform.tfvars` — `resend_dkim_txt` の値（DKIM 鍵）
- `terraform/cloudflare/terraform.tfvars.example` — コメントアウトされた `resend_dkim_txt` 行
- `docs/design/terraform-cloudflare.md` — mail DNS セクション（149〜231行目）および `resend_dkim_txt` 記述（283行目）
- `docs/design/secrets-1password.md` — mailserver-resend-secret に関する記述

ArgoCD は `manifests/*` を ApplicationSet でスキャンし、prune 有効で自動同期している。

## Goals / Non-Goals

**Goals:**
- mailserver に関するすべてのファイルをリポジトリから削除する
- kustomization.yaml 等の参照ファイルから mailserver エントリを除去する
- ドキュメントから mailserver への言及を削除する
- `terraform/cloudflare/dns_mail.tf` を削除し、手動で `terraform apply` を実行して Cloudflare DNS レコードをすべて削除する
- k8s-worker01 上の `/mnt/hdd/data/k8s/pv/mailserver/` を手動 SSH で削除する
- 1Password vault の `mailserver-resend-secret` アイテムを手動削除する

**Non-Goals:**
- 1Password vault アイテム以外の外部サービス側のデータ削除

## Decisions

### ArgoCD プルーニングに委ねる

`manifests/mailserver/` ディレクトリを削除して master にプッシュすれば、ArgoCD の ApplicationSet が `k8s-mailserver` Application を自動削除し、prune によりクラスタリソースも削除される。手動 `kubectl delete` は不要。

**代替案**: ArgoCD の `application-set.yaml` に `exclude: true` を追加してから削除する段階的アプローチ。ただし、prune 有効の場合は一括削除でも安全に機能するため不要。

### ファイル削除順序

Kustomize の整合性のため、参照ファイル（kustomization.yaml）の修正と対象ファイルの削除を同一コミットで行う。分割すると一時的に broken な状態になる可能性がある（ArgoCD は sync に失敗するが prune で最終的には解決する）。

## Risks / Trade-offs

- **PV データの喪失**: PV の reclaimPolicy が `Retain` であれば実データは残るが、PV 定義を削除することで kubectl からは参照できなくなる。`/mnt/hdd/data/k8s/pv/mailserver/` 配下のデータはホスト上に残り続ける（Non-Goals）。
  → Mitigation: 削除前にデータが不要であることを確認済み（廃止決定）

- **Certificate の削除**: cert-manager が発行した TLS 証明書が削除される。mailserver が使用していた外部 DNS レコードへの影響は別途確認が必要。
  → Mitigation: mailserver が廃止済みであるため影響なし

- **ESO の同期停止**: ExternalSecret 削除により mailserver-resend-secret の同期が止まる。1Password 側の vault アイテムは残存するが運用上問題なし。

- **DNS レコード削除は即時反映**: `terraform apply` 実行後、`mail.i-tk.dev` および Resend 用レコードが即座に削除される。外部からのメール受信・送信は完全に不可能になる。
  → Mitigation: mailserver が廃止済みのため影響なし

- **mailserver は現在稼働中**: ArgoCD の prune により `manifests/mailserver/` 削除時にクラスタリソースが自動削除される。削除タイミングは master push 後の ArgoCD sync に依存するが、いつ削除されても問題ないことを確認済み。
  → Mitigation: 特別な対応不要
