# 運用・バックアップ

## cron ジョブ（サーバー側）

`etc/root.crontab` をサーバーの root cron に登録する。主な処理:

| スケジュール | 処理 |
|-------------|------|
| 毎日 0:30 | システムレポート送信 |
| 毎日 5:30 | 古いバックアップの削除 |
| 毎週土曜 4:30 | Nextcloud・Growi フルバックアップ |
| 月〜金 4:30 | Nextcloud・Growi 増分バックアップ |
| 毎日 10:30 | Palworld バックアップを HDD に移動 |

バックアップスクリプト本体は `bin/cronjobs/` に格納されている。

## Growi アップデート手順

Growi は PV の claimRef 問題があるため、専用スクリプトで更新する:

```bash
./bin/update/update-growi.sh
```

スクリプトは以下を実行する:
1. `git pull` でマニフェストを更新
2. `kubectl kustomize --enable-helm` でレンダリング
3. 既存リソースを削除
4. PV の `claimRef.uid` を除去して再利用可能にする

## クラスタ初期セットアップ

1. `bin/install_k8s.sh` — containerd / kubelet / kubeadm / kubectl / Helm のインストール（Rocky Linux 想定）
2. `bin/create_k8s_cluster.sh` — `kubeadm init` と Calico のデプロイ
