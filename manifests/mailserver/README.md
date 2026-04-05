# mailserver

docker-mailserver on Kubernetes。個人ドメイン `i-tk.dev` のメール受信・送信を担う。

- 送信: Resend SMTP リレー (`smtp.resend.com:465`)
- 受信: SMTP (port 25), IMAPS (port 993)
- TLS: cert-manager (Cloudflare DNS-01)
- スパムフィルタ: Rspamd
- DKIM/DMARC: 有効

詳細設計は [docs/design/mailserver.md](../../docs/design/mailserver.md) を参照。

## メールアカウント管理

```bash
# アカウント追加
kubectl exec -n mailserver deploy/mailserver-docker-mailserver -- setup email add <user>@i-tk.dev

# アカウント一覧
kubectl exec -n mailserver deploy/mailserver-docker-mailserver -- setup email list

# パスワード変更
kubectl exec -n mailserver deploy/mailserver-docker-mailserver -- setup email update <user>@i-tk.dev

# アカウント削除
kubectl exec -n mailserver deploy/mailserver-docker-mailserver -- setup email del <user>@i-tk.dev
```

## エイリアス管理

```bash
# エイリアス追加（postmaster を別アカウントに転送）
kubectl exec -n mailserver deploy/mailserver-docker-mailserver -- setup alias add postmaster@i-tk.dev <user>@i-tk.dev

# エイリアス一覧
kubectl exec -n mailserver deploy/mailserver-docker-mailserver -- setup alias list

# エイリアス削除
kubectl exec -n mailserver deploy/mailserver-docker-mailserver -- setup alias del postmaster@i-tk.dev
```

## ログ確認

```bash
# メールログ
kubectl logs -n mailserver deploy/mailserver-docker-mailserver -f

# 直近の受信ログ
kubectl exec -n mailserver deploy/mailserver-docker-mailserver -- tail -50 /var/log/mail/mail.log

# DKIM 検証ログ
kubectl exec -n mailserver deploy/mailserver-docker-mailserver -- grep -i dkim /var/log/mail/mail.log | tail -20
```

## Secret 管理

Resend API キーは `credentials/mailserver/mailserver-resend-secret.env` に記載（gitignore 対象）。

```env
RELAY_PASSWORD=re_xxxxxxxxxxxxxxxx
```

変更後は以下を実行：

```bash
./bin/create_secrets.sh
kubectl apply -f secrets/mailserver/mailserver-resend-secret.yaml
```

## TLS 証明書確認

```bash
kubectl get certificate -n mailserver
kubectl describe certificate -n mailserver mailserver-tls
```

## 動作確認

```bash
# SMTP 接続確認（外部から）
nc -vz mail.i-tk.dev 25

# IMAPS 接続確認
openssl s_client -connect mail.i-tk.dev:993

# メールスコア確認
# https://www.mail-tester.com にアクセスしてテストメールを送信
```

## トラブルシューティング

```bash
# Pod の再起動
kubectl rollout restart deploy/mailserver-docker-mailserver -n mailserver

# PV の状態確認
kubectl get pv | grep mailserver

# キュー確認
kubectl exec -n mailserver deploy/mailserver-docker-mailserver -- mailq
```
