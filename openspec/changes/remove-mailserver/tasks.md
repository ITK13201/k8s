## 1. マニフェスト削除

- [x] 1.1 `manifests/mailserver/` ディレクトリ全体を削除し、`ls manifests/mailserver` が "No such file" になることを確認
- [x] 1.2 `manifests/namespaces/mailserver.yaml` を削除し、ファイルが存在しないことを確認
- [x] 1.3 `manifests/pv/mailserver-data.yaml`, `mailserver-state.yaml`, `mailserver-config.yaml`, `mailserver-log.yaml` の4ファイルを削除し、いずれもファイルが存在しないことを確認

## 2. kustomization.yaml の参照削除

- [x] 2.1 `manifests/namespaces/kustomization.yaml` から `- mailserver.yaml` の行を削除し、`kustomize build manifests/namespaces/` がエラーなく完了することを確認
- [x] 2.2 `manifests/pv/kustomization.yaml` から `mailserver-data.yaml`, `mailserver-state.yaml`, `mailserver-config.yaml`, `mailserver-log.yaml` の4行を削除し、`kustomize build --enable-helm manifests/pv/` がエラーなく完了することを確認

## 3. ドキュメント更新

- [x] 3.1 `docs/design/mailserver.md` を削除し、ファイルが存在しないことを確認
- [x] 3.2 `CLAUDE.md` から `[メールサーバ設計](docs/design/mailserver.md)` の行を削除し、リンクが残っていないことを確認
- [x] 3.3 `docs/applications.md` から mailserver に関する行（アプリ一覧行）を削除し、"mailserver" という文字列が残っていないことを確認
- [x] 3.4 `docs/secrets.md` から mailserver シークレット関連の記述（mailserver-resend-secret 等）を削除し、"mailserver" という文字列が残っていないことを確認
- [x] 3.5 `docs/design/secrets-1password.md` から mailserver 関連の記述（137・160・195・374行目付近）を削除し、"mailserver" という文字列が残っていないことを確認
- [x] 3.6 `docs/design/terraform-cloudflare.md` の mail DNS セクション（149〜231行目の mail/MX/SPF/DMARC/Resend レコード）を削除し、147行目の `}` 直後にコードブロックの閉じ ` ``` ` を追加して構造を維持する。また283行目付近の `resend_dkim_txt = "p=XXXX..."` 行も削除し、"mail" "resend" "dkim" という文字列が意図しない形で残っていないことを確認

## 4. Ansible 変数更新

- [x] 4.1 `ansible/inventory/group_vars/workers/main.yml` から mailserver の PV ディレクトリパス（`/mnt/hdd/data/k8s/pv/mailserver/*` 配下の4行）を削除し、"mailserver" という文字列が残っていないことを確認

## 5. Terraform Cloudflare DNS 削除

- [x] 5.1 `terraform/cloudflare/dns_mail.tf` を削除し、ファイルが存在しないことを確認
- [x] 5.2 `terraform/cloudflare/variables.tf` から `resend_dkim_txt` 変数定義（29〜33行目）を削除し、`terraform validate` がエラーなく通ることを確認
- [x] 5.3 `terraform/cloudflare/terraform.tfvars` から `resend_dkim_txt = "..."` 行を削除し、`resend_dkim` という文字列が残っていないことを確認
- [x] 5.4 `terraform/cloudflare/terraform.tfvars.example` からコメントアウトされた `# resend_dkim_txt = "p=XXXX..."` 行を削除し、`resend_dkim` という文字列が残っていないことを確認
- [x] 5.5 `terraform -chdir=terraform/cloudflare plan` を実行し、A/MX/SPF/DMARC/Resend DKIM/Return-Path の各 DNS レコードが destroy 対象になっていることをプレビューで確認
- [x] 5.6 （手動）`terraform -chdir=terraform/cloudflare apply` を実行し、DNS レコードが Cloudflare から削除されることを確認

## 6. クラスタ外リソースの手動削除

- [x] 6.1 （手動）k8s-worker01 に SSH ログインし、`sudo rm -rf /mnt/hdd/data/k8s/pv/mailserver/` を実行してホスト上のデータを削除し、ディレクトリが存在しないことを確認
- [x] 6.2 （手動）1Password vault から `mailserver-resend-secret` アイテムを削除し、vault 上に存在しないことを確認

## 7. 最終確認

- [x] 7.1 `grep -r "mailserver\|resend_dkim" manifests/ docs/ CLAUDE.md ansible/ terraform/` を実行し、意図しない残存参照がないことを確認（charts/ 配下は除外可）
- [ ] 7.2 変更を master にプッシュし、ArgoCD で `k8s-mailserver` Application が削除（pruned）されることを確認
