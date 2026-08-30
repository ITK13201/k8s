## 1. 1Password シークレット登録

- [x] 1.1 1Password Vault に `gomi-no-hi-secret` アイテムを作成し、`VAPID_PUBLIC_KEY`・`VAPID_PRIVATE_KEY`・`VAPID_SUBJECT`・`REDIS_PASSWORD` の4フィールドを登録する。確認: 1Password の Vault に 4 フィールドがすべて存在することを目視確認する
- [x] 1.2 1Password Vault に `gomi-no-hi-redis-secret` アイテムを作成し、`REDIS_PASSWORD` フィールドを 1.1 と同じ値で登録する。確認: アイテムが存在し REDIS_PASSWORD フィールドが設定されていることを目視確認する

## 2. Ansible PV ディレクトリ追加

- [x] 2.1 `ansible/inventory/group_vars/workers/main.yml` の `server_setup_k8s_pv_dirs` HDD セクション（`# HDD (/mnt/hdd/data/k8s/pv/)` 以下）に `/mnt/hdd/data/k8s/pv/gomi-no-hi/redis` を追加する。確認: `ansible-lint ansible/inventory/group_vars/workers/main.yml` がエラーなく通ること
- [ ] 2.2 `ansible-playbook playbooks/workers.yml --tags setup` を実行して worker ノードに `/mnt/hdd/data/k8s/pv/gomi-no-hi/redis` ディレクトリが作成されたことを確認する。確認: `ssh k8s-worker01 'ls -la /mnt/hdd/data/k8s/pv/gomi-no-hi/'` でディレクトリが存在すること

## 3. Namespace マニフェスト追加

- [x] 3.1 `manifests/namespaces/gomi-no-hi.yaml` を新規作成する（moneyrabbit.yaml を参考に Namespace リソースを定義）。確認: `kubectl apply --dry-run=client -f manifests/namespaces/gomi-no-hi.yaml` がエラーなく通ること
- [x] 3.2 `manifests/namespaces/kustomization.yaml` に `gomi-no-hi.yaml` を追記する。確認: `kustomize build manifests/namespaces/` で gomi-no-hi Namespace が出力されること

## 4. PersistentVolume マニフェスト追加

- [x] 4.1 `manifests/pv/gomi-no-hi-redis.yaml` を新規作成する（storageClass: manual、capacity: 1Gi、path: `/mnt/hdd/data/k8s/pv/gomi-no-hi/redis`、reclaimPolicy: Retain）。確認: `kubectl apply --dry-run=client -f manifests/pv/gomi-no-hi-redis.yaml` がエラーなく通ること
- [x] 4.2 `manifests/pv/kustomization.yaml` に `gomi-no-hi-redis.yaml` を追記する。確認: `kustomize build manifests/pv/` で gomi-no-hi-redis-pv が出力されること

## 5. gomi-no-hi マニフェスト作成

- [x] 5.1 `manifests/gomi-no-hi/values.yaml` を新規作成する（frontend/backend image tag: `2.0.0`・existingSecret: `gomi-no-hi-backend-secret`・redis storageClass: manual、size: 1Gi・redis existingSecret: `gomi-no-hi-redis-secret` を設定）。確認: ファイルが存在し yamlfmt で整形されること
- [x] 5.2 `manifests/gomi-no-hi/external-secret.yaml` を新規作成する（gomi-no-hi-backend-secret・gomi-no-hi-redis-secret の ExternalSecret を moneyrabbit の external-secret.yaml を参考に定義）。確認: `kubectl apply --dry-run=client -f manifests/gomi-no-hi/external-secret.yaml` がエラーなく通ること
- [x] 5.3 `manifests/gomi-no-hi/ingress-tailscale.yaml` を新規作成する（`/api` → backend:8080、`/` → frontend:80 のルーティング、TLS host: gomi-no-hi）。確認: `kubectl apply --dry-run=client -f manifests/gomi-no-hi/ingress-tailscale.yaml` がエラーなく通ること
- [x] 5.4 `manifests/gomi-no-hi/kustomization.yaml` を新規作成する（namespace: gomi-no-hi、resources に external-secret.yaml・ingress-tailscale.yaml を列挙、helmCharts で `repo: https://itk13201.github.io/gomi-no-hi` を参照）。確認: `kustomize build --enable-helm manifests/gomi-no-hi/` でエラーなくレンダリングされ、Deployment・Service・PVC・CronJob・Ingress が出力されること

## 6. ghcr-secret 手動作成（初回）

- [ ] 6.1 GitHub の Personal Access Token（スコープ: `read:packages`）を用いて `gomi-no-hi` Namespace に `ghcr-secret` を作成する。コマンド: `kubectl create secret docker-registry ghcr-secret --docker-server=ghcr.io --docker-username=<GitHubユーザー名> --docker-password=<PAT> -n gomi-no-hi`。確認: `kubectl get secret ghcr-secret -n gomi-no-hi` が存在し type が `kubernetes.io/dockerconfigjson` であること

## 7. ArgoCD 自動検出の確認

- [ ] 7.1 `manifests/argocd/application-set.yaml` の ApplicationSet は `manifests/*` を自動検出するため、**追記は不要**。master push 後に ArgoCD が `k8s-gomi-no-hi` アプリを自動生成することを確認する。確認: `kubectl get application k8s-gomi-no-hi -n argocd` が存在すること

## 8. デプロイ・動作確認

- [ ] 8.1 変更を master にプッシュし、ArgoCD が `gomi-no-hi` アプリを自動同期することを確認する。確認: `kubectl get pods -n gomi-no-hi` で全 Pod（frontend・backend・redis）が Running/Ready になること
- [ ] 8.2 Tailscale VPN 接続済みの端末から `https://gomi-no-hi.<tailnet>.ts.net/` にアクセスし、PWA フロントエンドが表示されることを確認する
- [ ] 8.3 ブラウザでプッシュ通知の許可を行い、サブスクリプションが登録されることを確認する（backend API の `/api/subscriptions` 等で確認、または CronJob の手動実行）。確認: Redis に購読データが保存されること（`kubectl exec -n gomi-no-hi <redis-pod> -- redis-cli KEYS '*'`）

## 9. 設計書作成

- [x] 9.1 `docs/design/gomi-no-hi.md` を新規作成し、コンポーネント構成・マニフェスト構成・シークレット設計・Tailscale Ingress 設計・実装手順を記載する（moneyrabbit.md を参考に）。確認: ファイルが存在し CLAUDE.md の設計書リストに追記されること
