## Purpose

チャット駆動で予定を登録できる個人用 PWA アプリ（CalendarRabbit）のデプロイ仕様。LLM（DeepSeek 既定 / Claude 切り戻し可）による自然言語からの予定抽出と、DeepSeek 経路での Tavily web 検索を提供する。

## Requirements

### Requirement: backend が LLM プロバイダを選択できること

CalendarRabbit backend は複数の LLM プロバイダから利用先を選択できること。
本番では DeepSeek を既定プロバイダとして利用し、必要に応じて Claude へ切り戻せること。
選択されたプロバイダに対応する認証情報が Secret 経由で backend に注入されること。

#### Scenario: DeepSeek が既定プロバイダとして有効になる
- **WHEN** backend が起動し、LLM プロバイダ設定が `deepseek` である
- **THEN** backend は自然言語からの予定抽出に DeepSeek API を利用する

#### Scenario: Claude へ切り戻せる
- **WHEN** LLM プロバイダ設定を `claude` に変更してデプロイする
- **THEN** backend は予定抽出に Claude API を利用する

### Requirement: DeepSeek 経路で web 検索が利用されること

DeepSeek プロバイダ利用時、backend は予定抽出の事前検索として web 検索プロバイダ（Tavily）を利用できること。
検索プロバイダの認証情報が Secret 経由で backend に注入されること。

#### Scenario: 事前検索で外部情報を補完する
- **WHEN** DeepSeek プロバイダが有効で、予定抽出に外部情報が必要な入力を受け取る
- **THEN** backend は Tavily 検索 API を呼び出して補完情報を取得したうえで予定を抽出する

### Requirement: backend シークレットが LLM/検索の認証情報を含むこと

`calendarrabbit-secret`（ESO + 1Password で管理される backend 用 Secret）は、
既存の `DB_PASSWORD`・`CLAUDE_API_KEY` に加え、`DEEPSEEK_API_KEY`・`SEARCH_API_KEY` を含むこと。
0.2.0 の backend Deployment はこれら 4 キーを `optional` 指定なしの `secretKeyRef` で参照するため、
いずれかが欠落すると backend Pod は起動できない。

#### Scenario: 全キーが揃っていれば backend Pod が起動する
- **WHEN** `calendarrabbit-secret` に `DB_PASSWORD`・`CLAUDE_API_KEY`・`DEEPSEEK_API_KEY`・`SEARCH_API_KEY` が揃っている
- **THEN** backend Pod は正常に起動しコンテナが Running になる

#### Scenario: 新規キーが欠落していると backend Pod が起動しない
- **WHEN** `DEEPSEEK_API_KEY` または `SEARCH_API_KEY` が `calendarrabbit-secret` に存在しない
- **THEN** backend Pod は `CreateContainerConfigError` となり起動しない

### Requirement: Helm チャートおよびアプリイメージが 0.2.0 であること

CalendarRabbit のデプロイは OCI レジストリ `oci://ghcr.io/itk13201` のチャートバージョン `0.2.0` を参照し、
frontend・backend のコンテナイメージ tag が `0.2.0` に固定されること。

#### Scenario: kustomize build が 0.2.0 チャートをレンダリングする
- **WHEN** `kustomize build --enable-helm manifests/calendarrabbit/` を実行する
- **THEN** チャートバージョン `0.2.0` が取得され、backend/frontend の image tag が `0.2.0` の Deployment がエラーなく出力される
