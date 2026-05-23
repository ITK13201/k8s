# CLAUDE.md — manifests/

Kubernetes マニフェストを Kustomize + Helm で管理するディレクトリ。ArgoCD が `master` への push で自動同期する。

## コマンド

```bash
# マニフェストをローカルでレンダリング（Helm含む）
# kubectl kustomize ではなく standalone の kustomize を使うこと
kustomize build --enable-helm ./manifests/<app>/

# Helm chart の values スキーマ確認（values を書く前に必ず実行）
helm show values <chart> --repo <repo-url> --version <version>
```

## ArgoCD ApplicationSet の除外アプリ

以下のアプリは `argocd/application-set.yaml` で **明示的に除外** されており、ArgoCD による自動同期対象外:

| アプリ | 備考 |
|--------|------|
| `growi` | 更新は `./bin/update/update-growi.sh` を使うこと（[docs/operations.md](../docs/operations.md) 参照） |
| `growi-converter` | 手動適用: `kubectl apply -k manifests/growi-converter/` |
| `minecraft` | 手動適用: `kubectl apply -k manifests/minecraft/` |
| `palworld` | 手動適用: `kubectl apply -k manifests/palworld/` |

## ディレクトリの命名

- `ingress/` — 各アプリの **Ingress リソース**（argocd.yaml, grafana.yaml など）を集約
- `ingress-nginx/` — ingress-nginx **コントローラ**本体の Helm values・kustomization

## Kubernetes API バージョン

- HPA は必ず `autoscaling/v2` を使うこと（`autoscaling/v1` は k8s v1.26 以降削除済み）
- Helm chart が `autoscaling/v1` を生成する場合は `values.yaml` で HPA を無効化し、独自リソースとして `hpa.yaml` を追加する

## バージョン固定

- `kubernetes-dashboard`: **v6 を維持**（v6→v7 は非互換アップグレード）
- 詳細は [docs/applications.md](../docs/applications.md) を参照

## kustomize helmCharts への namespace 非適用

kustomize 5.8.1 では `namespace:` フィールドが `helmCharts:` で生成されるリソースに適用されない。
- チャートが自身で namespace を設定している場合はパッチ不要（Tailscale Operator、MoneyRabbit v0.3.0+ など）
- チャートが設定しない場合の回避策: `kustomization.yaml` 内に種類ごとの JSON6902 パッチを追加する
  ```yaml
  patches:
  - patch: '[{"op":"add","path":"/metadata/namespace","value":"<ns>"}]'
    target:
      kind: Deployment
  ```

## PersistentVolume 管理

- PV は `pv/` で定義し、`reclaimPolicy: Retain` を使用
- ホストパスはストレージ種別で異なる（`ansible/inventory/group_vars/workers/main.yml` の `server_setup_k8s_pv_dirs` に全一覧）:
  - **SSD** (`/data/k8s/pv/<app>/`): 高速I/Oが必要なもの（minecraft, palworld など）
  - **HDD** (`/mnt/hdd/data/k8s/pv/<app>/`): 大容量が必要なもの（nextcloud, growi, monitoring など）
- ディレクトリ作成は Ansible `server_setup` ロールの `server_setup_k8s_pv_dirs` 変数で管理
- PV が `Released` 状態になった場合は `claimRef` を手動で削除して `Available` に戻す:
  ```bash
  kubectl patch pv <name> --type=json -p='[{"op":"remove","path":"/spec/claimRef"}]'
  ```

## Tailscale Operator

- Ingress の `name` が MagicDNS ホスト名 (`<name>.<tailnet>.ts.net`) になる
- Ingress ごとに proxy Pod が1つ作成される（複数アプリを別ホスト名で公開可能）
- 以下の事前条件を満たさないと Ingress が ADDRESS を取得できない:
  - Tailscale admin で HTTPS Certificates を有効化
  - ACL に `tag:k8s-operator`（Operator用）と `tag:k8s`（Proxy用）を定義し、`tag:k8s` の owner を `tag:k8s-operator` に設定
  - `operator-oauth` Secret を `tailscale` namespace に手動作成（`credentials/tailscale/operator-oauth.env` → `./bin/create_secrets.sh`）

## Renovate 自動マージポリシー

Renovate が以下を自動追跡する:
- YAML ファイル内の Docker イメージタグ
- `kustomization.yaml` 内の GitHub Release / GitHub raw URL

**non-0.x の minor/patch は自動マージ**。major バージョンアップは手動レビューが必要。

ArgoCD除外アプリ（growi, growi-converter, minecraft, palworld）はRenovateの`ignorePaths`でも追跡対象外。
