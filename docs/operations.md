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

1. **VM プロビジョニング** — Terraform で Proxmox VE 上に VM を作成（[docs/terraform.md](terraform.md) 参照）
2. **k8s クラスタ構築・ArgoCD デプロイ** — Ansible で一括セットアップ（[docs/ansible.md](ansible.md) 参照）

   ```bash
   ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml
   ```

3. **kubeconfig を手元に取得する**

   ```bash
   scp k8s@192.168.1.200:~/.kube/config ~/.kube/config
   ```

4. **シークレット適用** — ArgoCD がアプリを同期する前に手元から適用する

   ```bash
   kubectl apply -R -f secrets/
   ```

以降のアプリデプロイは ArgoCD が `master` への push を検知して自動同期する。
