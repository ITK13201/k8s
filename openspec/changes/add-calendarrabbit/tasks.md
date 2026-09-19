## 1. 1Password シークレット登録

- [ ] 1.1 1Password Vault に 2 アイテムを作成する: `calendarrabbit-backend-secret`（`CLAUDE_API_KEY`・`DB_PASSWORD`）と `calendarrabbit-mysql-secret`（`MYSQL_PASSWORD`・`MYSQL_ROOT_PASSWORD`）。`DB_PASSWORD` と `MYSQL_PASSWORD` は同一のアプリ用 DB パスワードにする。確認: 両アイテムが存在し全フィールドが登録され、DB_PASSWORD と MYSQL_PASSWORD が同値であることを目視確認する

## 2. Ansible PV ディレクトリ追加

- [x] 2.1 `ansible/inventory/group_vars/workers/main.yml` の `server_setup_k8s_pv_dirs` HDD セクション（`# HDD (/mnt/hdd/data/k8s/pv/)` 以下）に `/mnt/hdd/data/k8s/pv/calendarrabbit/mysql` を追加する。確認: `ansible-lint ansible/inventory/group_vars/workers/main.yml` がエラーなく通ること
- [ ] 2.2 `ansible-playbook playbooks/workers.yml --tags setup` を実行して worker ノードに `/mnt/hdd/data/k8s/pv/calendarrabbit/mysql` ディレクトリが作成されたことを確認する。確認: `ssh k8s-worker01 'ls -la /mnt/hdd/data/k8s/pv/calendarrabbit/'` でディレクトリが存在すること

## 3. Namespace マニフェスト追加

- [x] 3.1 `manifests/namespaces/calendarrabbit.yaml` を新規作成する（gomi-no-hi.yaml を参考に Namespace リソースを定義）。確認: `kubectl apply --dry-run=client -f manifests/namespaces/calendarrabbit.yaml` がエラーなく通ること
- [x] 3.2 `manifests/namespaces/kustomization.yaml` に `calendarrabbit.yaml` を追記する。確認: `kustomize build manifests/namespaces/` で calendarrabbit Namespace が出力されること

## 4. PersistentVolume マニフェスト追加

- [x] 4.1 `manifests/pv/calendarrabbit-mysql.yaml` を新規作成する（storageClass: manual、capacity: 5Gi、path: `/mnt/hdd/data/k8s/pv/calendarrabbit/mysql`、reclaimPolicy: Retain、gomi-no-hi-redis.yaml を参考に）。確認: `kubectl apply --dry-run=client -f manifests/pv/calendarrabbit-mysql.yaml` がエラーなく通ること
- [x] 4.2 `manifests/pv/kustomization.yaml` に `calendarrabbit-mysql.yaml` を追記する。確認: `kustomize build manifests/pv/` で calendarrabbit-mysql-pv が出力されること

## 5. calendarrabbit マニフェスト作成

- [x] 5.1 `manifests/calendarrabbit/values.yaml` を更新する（`fullnameOverride: calendarrabbit`、frontend/backend の image tag `0.0.1`、`backend.secret.existingSecret: calendarrabbit-backend-secret`・`mysql.secret.existingSecret: calendarrabbit-mysql-secret`、`mysql.persistence.storageClass: manual`・`mysql.persistence.size: 5Gi`、`backend.env.allowedOrigins` はチャート既定の `*`）。※旧トップレベル `secret.existingSecret` は削除する。確認: ファイルが存在し `yamlfmt manifests/calendarrabbit/values.yaml` で整形されること
- [x] 5.2 `manifests/calendarrabbit/external-secret.yaml` を更新する（`calendarrabbit-backend-secret`〔CLAUDE_API_KEY・DB_PASSWORD〕と `calendarrabbit-mysql-secret`〔MYSQL_PASSWORD・MYSQL_ROOT_PASSWORD〕の 2 つの ExternalSecret を定義し、それぞれ同名の 1Password アイテムから同期。gomi-no-hi の external-secret.yaml を参考に）。確認: `kubectl apply --dry-run=client -f manifests/calendarrabbit/external-secret.yaml` がエラーなく通り、ExternalSecret が 2 つ含まれること
- [x] 5.3 `manifests/calendarrabbit/ingress-tailscale.yaml` を新規作成する（`/api` → calendarrabbit-backend:8080、`/swagger` → calendarrabbit-backend:8080、`/` → calendarrabbit-frontend:80 のルーティング、`ingressClassName: tailscale`、TLS host: calendarrabbit）。確認: `kubectl apply --dry-run=client -f manifests/calendarrabbit/ingress-tailscale.yaml` がエラーなく通ること
- [x] 5.4 `manifests/calendarrabbit/kustomization.yaml` を確認する（namespace: calendarrabbit、resources に external-secret.yaml・ingress-tailscale.yaml、helmCharts で `repo: oci://ghcr.io/itk13201`・`name: calendarrabbit`・`version: 0.1.0`）。チャート 0.1.0 は同バージョンで再公開されたため、レンダリング前に kustomize/helm のチャートキャッシュ（および `manifests/calendarrabbit/charts/` の旧バンドルがあれば）をクリアする。確認: `kustomize build --enable-helm manifests/calendarrabbit/` で frontend/backend の Deployment・Service、MariaDB の StatefulSet・Service、Ingress、2 つの ExternalSecret が出力され、チャート生成の Secret（existingSecret 指定のため）が含まれないこと

## 6. OCI チャート可用性の確認（検証済み）

- [x] 6.1 OCI チャート `oci://ghcr.io/itk13201/calendarrabbit:0.1.0` が認証なしで pull できること、および `ghcr.io/itk13201/calendarrabbit-{backend,frontend}:0.0.1` が public であることを確認済み。`helm show chart oci://ghcr.io/itk13201/calendarrabbit --version 0.1.0` が chart メタデータを返し、両イメージの tags list に `0.0.1` が含まれることを確認した

## 7. ArgoCD 自動検出の確認

- [ ] 7.1 `manifests/argocd/application-set.yaml` の ApplicationSet は `manifests/*` を自動検出するため追記は不要。master push 後に ArgoCD が `k8s-calendarrabbit` アプリを自動生成することを確認する。確認: `kubectl get application k8s-calendarrabbit -n argocd` が存在すること

## 8. デプロイ・動作確認

- [ ] 8.1 変更を master にプッシュし、ArgoCD が `calendarrabbit` アプリを自動同期することを確認する。確認: `kubectl get pods -n calendarrabbit` で全 Pod（frontend・backend・mysql）が Running/Ready になること
- [ ] 8.2 backend/mysql の Secret が ESO 経由で作成されていることを確認する。確認: `kubectl get secret calendarrabbit-backend-secret calendarrabbit-mysql-secret -n calendarrabbit` が両方存在し、それぞれ 2 キー（backend: CLAUDE_API_KEY/DB_PASSWORD、mysql: MYSQL_PASSWORD/MYSQL_ROOT_PASSWORD）を含むこと
- [ ] 8.3 MariaDB PVC が manual PV にバインドされていることを確認する。確認: `kubectl get pvc -n calendarrabbit` の STATUS が Bound で、対象 PV が calendarrabbit-mysql-pv であること
- [ ] 8.4 Tailscale VPN 接続済みの端末から `https://calendarrabbit.<tailnet>.ts.net/` にアクセスし、PWA フロントエンドが表示されること、および `/api/health`・`/swagger` が応答することを確認する

## 9. 設計書作成

- [x] 9.1 `docs/design/calendarrabbit.md` を新規作成し、コンポーネント構成・マニフェスト構成・シークレット設計・OCI チャート参照・Tailscale Ingress 設計・実装手順を記載する（gomi-no-hi.md / moneyrabbit.md を参考に）。確認: ファイルが存在し、ルート `CLAUDE.md` の設計ドキュメント一覧に追記されていること
