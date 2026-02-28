# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 概要

ArgoCD (GitOps) + Kustomize + Helm で管理する個人用 Kubernetes インフラリポジトリ。
`master` へのプッシュが ArgoCD によって自動同期される。

## 主要コマンド

```bash
# マニフェストをローカルでレンダリング（Helm含む）
kubectl kustomize --enable-helm ./manifests/<app>/

# Secretの再生成
./bin/create_secrets.sh
```

## ドキュメント

- [アーキテクチャ](docs/architecture.md)
- [アプリケーション一覧・注意事項](docs/applications.md)
- [シークレット管理](docs/secrets.md)
- [ローカル開発 (Minikube)](docs/local-dev.md)
- [運用・バックアップ](docs/operations.md)