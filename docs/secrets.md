# シークレット管理

## ワークフロー

1. `credentials/<namespace>/<secret-name>.env` に `.env` 形式で値を記載する
2. `./bin/create_secrets.sh` を実行すると `secrets/<namespace>/<secret-name>.yaml` が生成される
3. 生成された Secret YAML をクラスタに適用する

`credentials/` は gitignore 対象。`secrets/` はリポジトリで管理される。

## スクリプトの動作

`bin/create_secrets.sh` は `kubectl create secret generic --dry-run=client --from-env-file` を使い、Secret YAML を生成して `secrets/` に書き出す。
