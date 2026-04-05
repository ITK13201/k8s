# メールサーバ設計書（docker-mailserver）

## 概要

docker-mailserver を Kubernetes 上に構築し、個人ドメイン (`i-tk.dev`) のメール**受信**を担う。
**送信は Resend SMTP リレー**を経由するため、docker-mailserver は受信専用サーバとして動作する。
公式 Helm chart (`docker-mailserver/docker-mailserver` v5.1.1 / app v15.1.0) を使用する。

> **注意**: docker-mailserver の Kubernetes 対応はコミュニティサポートであり、公式サポートではない。

## 要件

| 項目 | 内容 |
|------|------|
| メールドメイン | `i-tk.dev` |
| ホスト名 | `mail.i-tk.dev` |
| 受信プロトコル | SMTP 受信 (25), IMAPS (993) |
| 送信 | Resend SMTP リレー（`smtp.resend.com:465`） |
| 内部アプリ送信 | クラスタ内アプリ → docker-mailserver (587) → Resend リレー |
| TLS | cert-manager (Cloudflare DNS-01) |
| スパムフィルタ | Rspamd (受信フィルタ) |
| DKIM 検証 | 受信時に検証（署名は Resend が担当） |
| アンチウイルス | ClamAV 無効（メモリ消費が大きいため） |

## アーキテクチャ

```
【受信フロー】
外部 MTA (Gmail 等)
    ↓ port 25
ルーター (ポートフォワード: 25 → 192.168.1.201)
    ↓
k8s-worker01 (192.168.1.201)  ← hostPort
    ↓
mailserver Pod (namespace: mailserver)
    ↓
IMAP クライアント (MUA) ← port 993

【送信フロー: クラスタ内アプリ】
クラスタ内アプリ
    ↓ port 587 (cluster-internal)
mailserver Pod
    ↓ SMTP AUTH
Resend (smtp.resend.com:465)
    ↓
宛先 MTA

【送信フロー: 外部 MUA】
MUA (Thunderbird 等)
    ↓ SMTP AUTH (smtp.resend.com:465)
Resend
    ↓
宛先 MTA
```

### ポート公開方式: hostPort（シングルワーカー構成向け）

現在のクラスタはワーカーノード 1 台構成のため、Pod の `hostPort` でワーカーノードのポートに直接バインドする。

| ポート | 公開範囲 | 用途 |
|--------|---------|------|
| 25 | 外部公開 | SMTP 受信（外部 MTA からのメール受け取り） |
| 587 | クラスタ内のみ | Submission（クラスタ内アプリ → Resend リレー） |
| 993 | 外部公開 | IMAPS（MUA からのメール取得） |

> ポート 465 は Resend SMTP (SMTPS) として使用。

### ワーカー追加時の移行先: ingress-nginx TCP PROXY Protocol

複数ワーカーに拡張する場合は、ingress-nginx の TCP proxy + PROXY Protocol に移行する。

```yaml
# ingress-nginx values.yaml に追加
tcp:
  "25": "mailserver/mailserver:25::PROXY"
  "993": "mailserver/mailserver:993::PROXY"
```

## ディレクトリ構成

```
manifests/mailserver/
├── kustomization.yaml        # Helm chart 宣言
├── values.yaml               # Helm values
├── certificate.yaml          # cert-manager Certificate リソース
└── external-secret.yaml      # 1Password 連携（Issue #140 実装後）

manifests/namespaces/
└── mailserver.yaml           # Namespace 追加

manifests/pv/
├── mailserver-data.yaml      # PersistentVolume (受信メールデータ)
├── mailserver-state.yaml     # PersistentVolume (サービス状態)
├── mailserver-config.yaml    # PersistentVolume (設定・鍵)
└── mailserver-log.yaml       # PersistentVolume (ログ)
```

## マニフェスト詳細

### kustomization.yaml

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
helmCharts:
- name: docker-mailserver
  repo: https://docker-mailserver.github.io/docker-mailserver-helm
  version: 5.1.1
  releaseName: mailserver
  namespace: mailserver
  valuesFile: values.yaml
  valuesMerge: override
resources:
- certificate.yaml
```

### values.yaml

```yaml
---
deployment:
  env:
    OVERRIDE_HOSTNAME: mail.i-tk.dev
    # DKIM は受信検証のみ有効（送信署名は Resend が担当）
    ENABLE_OPENDKIM: "1"
    ENABLE_OPENDMARC: "1"
    ENABLE_RSPAMD: "1"
    ENABLE_CLAMAV: "0"
    ENABLE_FAIL2BAN: "1"
    SSL_TYPE: manual
    SSL_CERT_PATH: /secrets/tls.crt
    SSL_KEY_PATH: /secrets/tls.key
    # Resend SMTP リレー設定
    RELAY_HOST: smtp.resend.com
    RELAY_PORT: "465"
    RELAY_USER: resend
  envFrom:
  - secretRef:
      name: mailserver-resend-secret   # RELAY_PASSWORD を注入
  # hostPort でワーカーノードのポートに直接バインド
  hostPorts:
    enabled: true
  extraVolumes:
  - name: tls-secret
    secret:
      secretName: mailserver-tls
  extraVolumeMounts:
  - name: tls-secret
    mountPath: /secrets
    readOnly: true

certificate: "mailserver-tls"

persistence:
  config:
    enabled: true
    size: 1Gi
    storageClass: manual
    accessMode: ReadWriteOnce
  data:
    enabled: true
    size: 20Gi
    storageClass: manual
    accessMode: ReadWriteOnce
  state:
    enabled: true
    size: 1Gi
    storageClass: manual
    accessMode: ReadWriteOnce
  log:
    enabled: true
    size: 5Gi
    storageClass: manual
    accessMode: ReadWriteOnce

resources:
  requests:
    cpu: 500m
    memory: 1536Mi
  limits:
    cpu: 2000m
    memory: 2048Mi

# ワーカーノードにスケジュール固定（hostPort のため）
nodeSelector:
  kubernetes.io/hostname: k8s-worker01
```

### certificate.yaml（cert-manager）

```yaml
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: mailserver-tls
  namespace: mailserver
spec:
  secretName: mailserver-tls
  issuerRef:
    name: letsencrypt
    kind: ClusterIssuer
  dnsNames:
  - mail.i-tk.dev
  privateKey:
    algorithm: ECDSA
    size: 384
```

### PersistentVolume（例: data）

```yaml
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mailserver-data-pv
  labels:
    target-app: mailserver-data
spec:
  capacity:
    storage: 20Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  local:
    path: /data/k8s/pv/mailserver/data
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: Exists
```

## シークレット管理

Resend API キーを Secret として管理する。

```env
# credentials/mailserver/mailserver-resend-secret.env
RELAY_PASSWORD=<Resend API Key>
```

Issue #140（1Password 移行）完了後は ExternalSecret に変更する。

## DNS レコード設定（Cloudflare）

| タイプ | 名前 | 値 | 備考 |
|--------|------|----|------|
| A | `mail` | `<自宅グローバルIP>` | ルーターの WAN IP |
| MX | `@` | `mail.i-tk.dev` | Priority: 10 |
| TXT | `@` | `v=spf1 include:amazonses.com -all` | SPF（Resend のみ許可） |
| TXT | `_dmarc` | `v=DMARC1; p=quarantine; rua=mailto:postmaster@i-tk.dev` | DMARC |
| TXT | `resend._domainkey` | （Resend が発行する値） | Resend DKIM |
| MX | `send` | `feedback-smtp.ap-northeast-1.amazonses.com` | Resend Return-Path |
| TXT | `send` | `v=spf1 include:amazonses.com ~all` | Resend Return-Path SPF |

> **SPF の注意**: 送信は Resend のみを経由するため `include:amazonses.com -all` とする。

### Resend ドメイン認証

Resend ダッシュボード「Domains」で `i-tk.dev` を登録し、発行される DNS レコードを Cloudflare に設定する。Resend がアウトバウンドの DKIM 署名を行う。

## DKIM（受信検証）

docker-mailserver の OpenDKIM は受信メールの DKIM 検証のみを行う。送信用の DKIM 鍵生成は不要。

```bash
# 受信検証が正常に動作しているか確認
kubectl exec -n mailserver deploy/mailserver -- grep -i dkim /var/log/mail/mail.log
```

## メールアカウント管理

```bash
# アカウント追加
kubectl exec -n mailserver deploy/mailserver -- setup email add <user>@i-tk.dev <password>

# アカウント一覧
kubectl exec -n mailserver deploy/mailserver -- setup email list

# エイリアス追加（postmaster をメインアカウントに転送）
kubectl exec -n mailserver deploy/mailserver -- setup alias add postmaster@i-tk.dev <user>@i-tk.dev
```

## ルーター設定

ワーカーノード (192.168.1.201) へのポートフォワードを設定する。

| 外部ポート | 内部 IP | 内部ポート | 用途 |
|-----------|--------|-----------|------|
| 25 | 192.168.1.201 | 25 | SMTP 受信 |
| 993 | 192.168.1.201 | 993 | IMAPS |

> ポート 587 は外部公開不要（クラスタ内アプリからの送信のみ使用）。

## セットアップ手順

1. **Resend 設定**
   - Resend アカウントで API キーを発行
   - 「Domains」で `i-tk.dev` のドメイン認証を完了し、DNS レコードを Cloudflare に登録

2. **Namespace 追加**
   `manifests/namespaces/mailserver.yaml` を作成し `kustomization.yaml` に追加

3. **PV 作成**
   `manifests/pv/` に PV 4 本を追加し、ワーカーノードにディレクトリを作成:
   ```bash
   ssh k8s@192.168.1.201 "sudo mkdir -p /data/k8s/pv/mailserver/{data,state,config,log}"
   ```

4. **シークレット作成**
   `credentials/mailserver/mailserver-resend-secret.env` に Resend API キーを記載し `./bin/create_secrets.sh` を実行

5. **マニフェスト作成・プッシュ**
   `manifests/mailserver/` を作成し `master` にプッシュ → ArgoCD が自動同期

6. **証明書発行確認**
   cert-manager が `mailserver-tls` Secret を発行するまで待機:
   ```bash
   kubectl get certificate -n mailserver -w
   ```

7. **DNS レコード設定**
   Cloudflare に A / MX / SPF / DMARC レコードを設定

8. **メールアカウント作成**
   ```bash
   kubectl exec -n mailserver deploy/mailserver -- setup email add postmaster@i-tk.dev <password>
   ```

9. **ルーターのポートフォワード設定**（25, 993）

10. **動作確認**
    - 外部から `postmaster@i-tk.dev` にテストメールを送信し受信を確認
    - クラスタ内アプリからの送信テスト
    - [mail-tester.com](https://www.mail-tester.com) でメールスコアを確認

## 参考

- [docker-mailserver Helm Chart](https://docker-mailserver.github.io/docker-mailserver-helm/)
- [Kubernetes 上での設定（公式）](https://docker-mailserver.github.io/docker-mailserver/latest/config/advanced/kubernetes/)
- [Resend ドキュメント](https://resend.com/docs)
- [Artifact Hub](https://artifacthub.io/packages/helm/docker-mailserver/docker-mailserver)
