# ローカル開発 (Minikube)

## クラスタ操作

```bash
# 起動
minikube start --cpus=4 --memory=8192

# 削除
minikube delete

# LoadBalancer 用トンネル
minikube tunnel

# プロファイル一覧表示
minikube profile list
```

## アドオン

```bash
# 利用可能なアドオン一覧
minikube addons list

# Kubernetes Dashboard を開く
minikube dashboard
```

## ローカルイメージの利用

```bash
minikube image load <IMAGE>:<TAG>
```

**注意**: ローカルイメージには `latest` 以外のタグを必ず付けること。

## VM 内ディレクトリの作成

```bash
minikube ssh
mkdir <PATH>
```
