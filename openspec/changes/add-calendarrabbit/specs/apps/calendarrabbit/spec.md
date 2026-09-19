## Purpose

チャット駆動で予定を登録できる PWA アプリ「CalendarRabbit」を Kubernetes クラスタ上で稼働させ、Tailscale VPN 経由でのみアクセス可能にする。frontend・backend・MariaDB の 3 コンポーネントを Helm チャート（OCI レジストリ参照）でデプロイし、ArgoCD で GitOps 管理する。

## ADDED Requirements

### Requirement: アプリケーションが Tailscale VPN 経由でアクセス可能であること

CalendarRabbit frontend（PWA）と backend（API）が Kubernetes クラスタ上で稼働し、
Tailscale Ingress 経由で `calendarrabbit.<tailnet>.ts.net` という MagicDNS 名でアクセスできること。
インターネットには公開されない。

#### Scenario: Tailscale VPN 接続済み端末からフロントエンドにアクセスできる
- **WHEN** Tailscale VPN に接続済みの端末が `https://calendarrabbit.<tailnet>.ts.net/` にアクセスする
- **THEN** CalendarRabbit PWA フロントエンドが応答を返す

#### Scenario: Tailscale VPN 接続済み端末から API にアクセスできる
- **WHEN** Tailscale VPN に接続済みの端末が `https://calendarrabbit.<tailnet>.ts.net/api/` 以下のエンドポイントにアクセスする
- **THEN** CalendarRabbit バックエンド API が応答を返す

#### Scenario: Swagger UI にアクセスできる
- **WHEN** Tailscale VPN に接続済みの端末が `https://calendarrabbit.<tailnet>.ts.net/swagger/` にアクセスする
- **THEN** バックエンドが提供する Swagger UI が応答を返す

#### Scenario: VPN 未接続端末はアクセスできない
- **WHEN** Tailscale VPN に接続していない端末が CalendarRabbit にアクセスしようとする
- **THEN** 接続が拒否される（Tailscale MagicDNS で名前解決できない、またはルーティングされない）

### Requirement: Helm チャートが OCI レジストリから参照されること

CalendarRabbit の Helm チャートは OCI レジストリ `oci://ghcr.io/itk13201`（chart 名 `calendarrabbit`）から参照され、kustomize の `--enable-helm` によってレンダリングされること。

#### Scenario: kustomize build が OCI チャートをレンダリングする
- **WHEN** `kustomize build --enable-helm manifests/calendarrabbit/` を実行する
- **THEN** OCI レジストリからチャートが取得され、frontend・backend の Deployment/Service、MariaDB の StatefulSet/Service、Ingress がエラーなく出力される

### Requirement: MariaDB データが永続化されること

MariaDB StatefulSet の volumeClaimTemplate が `manual` storageClass の PersistentVolume にバインドされ、Pod 再起動後もデータが失われないこと。

#### Scenario: Pod 再起動後もデータが保持される
- **WHEN** MariaDB Pod が再起動する
- **THEN** 再起動前に登録された予定データが引き続き参照できる

#### Scenario: PVC が manual PV にバインドされる
- **WHEN** MariaDB StatefulSet がデプロイされる
- **THEN** volumeClaimTemplate から生成される PVC が `/mnt/hdd/data/k8s/pv/calendarrabbit/mysql` を指す PersistentVolume にバインドされる

### Requirement: シークレットが ESO + 1Password で管理されること

Claude API キーと DB パスワード（アプリ用・root）は 1Password Vault から ESO 経由で Kubernetes Secret として同期されること。シークレットのプレーンテキストはリポジトリにコミットされない。

#### Scenario: ExternalSecret が Secret を作成する
- **WHEN** ExternalSecret リソースが存在し、1Password Connect が稼働している
- **THEN** `calendarrabbit-backend-secret`（`CLAUDE_API_KEY`・`DB_PASSWORD`）および `calendarrabbit-mysql-secret`（`MYSQL_PASSWORD`・`MYSQL_ROOT_PASSWORD`）という名前の Kubernetes Secret が `calendarrabbit` Namespace に作成される

#### Scenario: チャートが既存 Secret を参照する
- **WHEN** Helm values で `backend.secret.existingSecret: calendarrabbit-backend-secret` および `mysql.secret.existingSecret: calendarrabbit-mysql-secret` を指定する
- **THEN** チャートは自前の Secret を生成せず、backend が `calendarrabbit-backend-secret` を、MariaDB が `calendarrabbit-mysql-secret` を参照する

### Requirement: ArgoCD による GitOps 管理がされること

`manifests/calendarrabbit/` への変更が master ブランチにプッシュされると、ArgoCD が自動で同期（prune 有効）すること。

#### Scenario: マニフェスト変更が自動同期される
- **WHEN** `manifests/calendarrabbit/` 配下のファイルが master ブランチに push される
- **THEN** ArgoCD が変更を検知して自動的にクラスタに適用する（`k8s-calendarrabbit` アプリが自動生成される）
