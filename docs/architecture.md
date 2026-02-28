# アーキテクチャ

## GitOps フロー

ArgoCD が本リポジトリを監視する。`manifests/argocd/application-set.yaml` の ApplicationSet が `manifests/` 配下の各ディレクトリに対して ArgoCD Application を自動生成する。`master` へのプッシュで自動同期（prune 有効）が走る。

## ディレクトリ構成

```
manifests/<app>/          # アプリごとのマニフェスト
  kustomization.yaml      # エントリポイント（helmCharts ブロックで依存 Helm Chart を宣言）
manifests/namespaces/     # Namespace 定義
manifests/pv/             # PersistentVolume 定義（ノードのホストパス /data/k8s/pv/ を使用）
bin/                      # クラスタセットアップ・運用スクリプト
credentials/<ns>/         # .env ファイル（gitignore 対象）
secrets/<ns>/             # 生成済み Secret YAML
etc/                      # cron 設定など
```

## マニフェスト構造

各アプリは `manifests/<app>/kustomization.yaml` をエントリポイントとする。Helm チャートの依存（主に Bitnami）は `helmCharts:` ブロックで宣言し、`kubectl kustomize --enable-helm` でレンダリングする。

## 依存更新（Renovate）

Renovate が以下を自動追跡し、non-0.x の minor/patch は自動マージ:
- YAML ファイル内の Docker イメージタグ
- `kustomization.yaml` 内の GitHub Release / GitHub raw URL
