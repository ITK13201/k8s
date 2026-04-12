# ログ集約設計書（Grafana Loki + Promtail）

## 1. 概要

### 1.1 目的

クラスタ上のすべてのアプリPodログをLokiに集約し、既存のGrafana（kube-prometheus-stack）からWebブラウザで検索・閲覧できるようにする。

### 1.2 スコープ

- Promtail DaemonSetによる全Podログの収集
- Lokiによるログの保存・クエリ
- 既存GrafanaへのLokiデータソース追加（別途UIは不要）

### 1.3 採用技術の選定理由

| 候補 | 採点 | 理由 |
|------|------|------|
| **Grafana Loki + Promtail** | ✅ 採用 | 既存GrafanaとUIを統合できる。軽量（Loki ~1GB RAM）。設計書Phase 4で既定 |
| EFK（Elasticsearch + Fluentd + Kibana） | ❌ 非採用 | ElasticsearchはGrowiに既存。KibanaでUIが増える。重い |
| OpenSearch + Fluent Bit | ❌ 非採用 | EFKと同様の問題 |

## 2. アーキテクチャ設計

```
┌─────────────────────────────────────────────────────────┐
│  Kubernetes Cluster                                      │
│                                                          │
│  ┌──────────────┐     ┌──────────────┐                  │
│  │  Pod (App A) │     │  Pod (App B) │  ...             │
│  └──────┬───────┘     └──────┬───────┘                  │
│         │ /var/log/pods/      │                          │
│  ┌──────▼─────────────────────▼──────────────────────┐  │
│  │  Promtail DaemonSet (monitoring namespace)        │  │
│  │  - 各ノードのコンテナログをtail                     │  │
│  │  - Podラベルをメタデータとして付与                  │  │
│  └──────────────────────┬────────────────────────────┘  │
│                          │ Push (HTTP)                   │
│  ┌───────────────────────▼────────────────────────────┐  │
│  │  Loki (monitoring namespace)                       │  │
│  │  - ログの受信・インデックス・保存                   │  │
│  │  - PV: /mnt/hdd/data/k8s/pv/monitoring/loki        │  │
│  └───────────────────────┬────────────────────────────┘  │
│                          │ LogQLクエリ                   │
│  ┌───────────────────────▼────────────────────────────┐  │
│  │  Grafana (monitoring namespace)                    │  │
│  │  - Lokiをデータソースとして追加                     │  │
│  │  - Explore画面でログ検索                            │  │
│  │  - ダッシュボードにログパネルを追加可能             │  │
│  └───────────────────────┬────────────────────────────┘  │
│                          │ HTTPS                         │
└──────────────────────────┼──────────────────────────────┘
                           │
                      ブラウザ（ユーザー）
                      grafana.<domain>
```

## 3. コンポーネント設計

### 3.1 Loki

| 項目 | 値 |
|------|----|
| デプロイモード | **Single binary（monolith）** |
| Helm Chart | `grafana/loki` |
| Namespace | `monitoring` |
| レプリカ | 1（個人クラスタのためHA不要） |
| ログ保持期間 | 30日 |
| ストレージ | Local PV 30Gi |
| リソース | requests: CPU 100m / RAM 256Mi、limits: CPU 1 / RAM 1Gi |

Single binaryモードを選択した理由:
- 2ノードの小規模クラスタでHA・スケーリング不要
- Microservicesモードより設定が単純
- リソース消費が少ない

### 3.2 Promtail

| 項目 | 値 |
|------|----|
| デプロイ形式 | DaemonSet（全ノードに配置） |
| Helm Chart | `grafana/promtail` |
| Namespace | `monitoring` |
| 収集対象 | `/var/log/pods/`配下の全コンテナログ |
| リソース | requests: CPU 50m / RAM 64Mi、limits: CPU 200m / RAM 256Mi |

### 3.3 Grafana（既存の変更）

既存`manifests/monitoring/values.yaml`の`grafana.additionalDataSources`にLokiを追加する:

```yaml
grafana:
  additionalDataSources:
    - name: Loki
      type: loki
      url: http://loki:3100
      access: proxy
      isDefault: false
```

同じnamespaceのため短いService名で解決できる。

## 4. ストレージ設計

| リソース | 容量 | ホストパス | reclaimPolicy |
|---------|------|-----------|---------------|
| loki PV | 30Gi | `/mnt/hdd/data/k8s/pv/monitoring/loki` | Retain |

他のmonitoring PV（Prometheus: `/mnt/hdd/data/k8s/pv/monitoring/prometheus`、Grafana: `/mnt/hdd/data/k8s/pv/monitoring/grafana`）と同じパターン。

- PV定義: `manifests/pv/loki.yaml`
- AnsibleのHDDディレクトリ変数に`/mnt/hdd/data/k8s/pv/monitoring/loki`を追加する

## 5. マニフェスト構成

```
manifests/
├── pv/
│   ├── kustomization.yaml       # loki.yaml を追加
│   └── loki.yaml                # 新規作成
└── monitoring/                  # 既存ディレクトリ
    ├── kustomization.yaml       # helmCharts に loki, promtail を追加
    ├── loki-values.yaml         # Loki Helm values（新規作成）
    ├── promtail-values.yaml     # Promtail Helm values（新規作成）
    ├── loki-pvc.yaml            # Loki PVC（新規作成）
    └── values.yaml              # grafana.additionalDataSources にLoki追加（既存変更）
```

namespaceは`monitoring`を再利用するため`manifests/namespaces/`への追加は不要。

## 6. ApplicationSetへの追加

`manifests/monitoring/`はすでにApplicationSetで管理されているため、追加設定不要。
LokiとPromtailのリソースが`k8s-monitoring` Applicationとして一緒に同期される。

## 7. リソース見積もり

| コンポーネント | CPU request | RAM request | 備考 |
|-------------|-------------|-------------|------|
| Loki | 100m | 256Mi | ログ保存・クエリ |
| Promtail × 2（ノード数） | 100m | 128Mi | DaemonSet（cp01 + worker01） |
| **合計追加分** | **200m** | **384Mi** | worker01の空きリソース内に収まる |

## 8. 実装手順

1. **AnsibleのHDDディレクトリ変数に追加**
   - 該当ロールのHDDディレクトリ変数に`/mnt/hdd/data/k8s/pv/monitoring/loki`を追加
   - `ansible-playbook playbooks/workers.yml`でディレクトリ作成

2. **マニフェスト作成**
   - `manifests/pv/loki.yaml`を作成
   - `manifests/monitoring/loki-values.yaml`を作成
   - `manifests/monitoring/promtail-values.yaml`を作成
   - `manifests/monitoring/loki-pvc.yaml`を作成

3. **既存ファイルの変更**
   - `manifests/monitoring/kustomization.yaml`にloki・promtailのhelmChartsを追加
   - `manifests/monitoring/values.yaml`の`grafana.additionalDataSources`にLokiを追加
   - `manifests/pv/kustomization.yaml`に`loki.yaml`を追加

4. **Git push → ArgoCD自動同期**

5. **動作確認**
   - GrafanaのExplore画面でLokiデータソースを選択しログが表示されることを確認
   - `{namespace="nextcloud"}`などのLogQLクエリでフィルタリング確認

## 9. 注意事項

### Promtailのクラスタ権限

Promtailは全namespaceのPodログを読むためClusterRoleが必要。Helm chartがデフォルトで作成するため追加設定不要。

### kustomize helmChartsとnamespace

CLAUDE.mdの制約「kustomize helmChartsへのnamespace非適用」の回避策として、JSON6902パッチで各リソースに`namespace: monitoring`を付与する。

### Growi ElasticsearchとLokiの共存

GrowiはElasticsearchをログ検索に使用しているが、用途が異なるため影響なし。

## 10. 進捗

| フェーズ | ステータス |
|---------|----------|
| 設計書作成 | ✅ 完了 |
| マニフェスト作成 | ✅ 完了 |
| AnsibleのPVディレクトリ追加 | ✅ 完了 |
| 本番環境デプロイ | ⏳ 未実施 |
| 動作確認 | ⏳ 未実施 |
