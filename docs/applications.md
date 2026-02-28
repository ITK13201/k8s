# アプリケーション一覧・注意事項

## 一覧

| アプリ | Namespace | 依存 Helm Chart |
|--------|-----------|-----------------|
| ArgoCD | argocd | - |
| cert-manager | cert-manager | - |
| ingress-nginx | ingress-nginx | - |
| kubernetes-dashboard | kubernetes-dashboard | - |
| Growi | growi | MongoDB, Elasticsearch (Bitnami) |
| Nextcloud | nextcloud | - |
| Monitoring | monitoring | kube-prometheus-stack（`manifests/monitoring/charts/` にバンドル） |
| Palworld | palworld | - |
| Minecraft | minecraft | MariaDB (Bitnami) |
| rss-generator | rss-generator | MariaDB (Bitnami) |
| rss-notifier | rss-notifier | MariaDB (Bitnami) |
| growi-converter | growi-converter | - |

## バージョン固定の注意事項

### kubernetes-dashboard
- **v6 を維持すること**。v6 → v7 は互換性なしのアップグレードのため。

### Growi
- **v7.0.3 を維持すること**。v7.0.9 以降でエディタ画面の MongoDB 認証エラーが発生することを確認済み。v7.0.3〜v7.0.9 の間は未検証。
