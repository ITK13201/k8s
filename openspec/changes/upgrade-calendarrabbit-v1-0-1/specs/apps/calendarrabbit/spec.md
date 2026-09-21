## ADDED Requirements

### Requirement: backend が Google Calendar 連携をサポートすること

CalendarRabbit backend は OAuth 2.0 により Google Calendar と連携し、抽出した予定を Google Calendar に登録できること。
連携には非機密設定 `googleOAuthClientID`・`googleOAuthRedirectURL`（`values.yaml` の `backend.env`）と、
機密情報 `GOOGLE_OAUTH_CLIENT_SECRET`・`GOOGLE_TOKEN_ENC_KEY`（Secret 経由）が backend に注入されること。
機密情報が空の場合、連携は休眠し既存機能（予定抽出）には影響しないこと。

#### Scenario: 連携が有効化され予定を Google Calendar に登録できる
- **WHEN** `googleOAuthClientID`・`googleOAuthRedirectURL` が設定され、Secret に `GOOGLE_OAUTH_CLIENT_SECRET`・`GOOGLE_TOKEN_ENC_KEY` の実値が存在する
- **THEN** backend は Google OAuth フローを提供し、ユーザー認可後に抽出した予定を Google Calendar に登録できる

#### Scenario: 機密情報が空なら連携は休眠する
- **WHEN** `GOOGLE_OAUTH_CLIENT_SECRET`・`GOOGLE_TOKEN_ENC_KEY` が空文字である
- **THEN** Google Calendar 連携は起動せず、backend は従来どおり予定抽出のみを提供する

### Requirement: Helm チャートが 1.0.2・アプリイメージが 1.0.0 であること

CalendarRabbit のデプロイは OCI レジストリ `oci://ghcr.io/itk13201` のチャートバージョン `1.0.2` を参照し、
frontend・backend のコンテナイメージ tag が `1.0.0` に固定されること。
`1.0.2` チャートの `appVersion` は `1.0.0` であり、`1.0.2` のアプリイメージは発行されていないため image tag は `1.0.0` を用いること。

#### Scenario: kustomize build が 1.0.2 チャートと 1.0.0 イメージをレンダリングする
- **WHEN** `kustomize build --enable-helm manifests/calendarrabbit/` を実行する
- **THEN** チャートバージョン `1.0.2` が取得され、backend/frontend の image tag が `1.0.0` の Deployment がエラーなく出力される

## MODIFIED Requirements

### Requirement: backend シークレットが LLM/検索の認証情報を含むこと

`calendarrabbit-secret`（ESO + 1Password で管理される backend 用 Secret）は、
既存の `DB_PASSWORD`・`CLAUDE_API_KEY`・`DEEPSEEK_API_KEY`・`SEARCH_API_KEY` に加え、
Google Calendar 連携用の `GOOGLE_OAUTH_CLIENT_SECRET`・`GOOGLE_TOKEN_ENC_KEY` を含むこと。
`1.0.2` の backend Deployment はこれら 6 キーを `optional` 指定なしの `secretKeyRef` で参照するため、
いずれかが欠落すると backend Pod は起動できない。

#### Scenario: 全キーが揃っていれば backend Pod が起動する
- **WHEN** `calendarrabbit-secret` に `DB_PASSWORD`・`CLAUDE_API_KEY`・`DEEPSEEK_API_KEY`・`SEARCH_API_KEY`・`GOOGLE_OAUTH_CLIENT_SECRET`・`GOOGLE_TOKEN_ENC_KEY` の 6 キーが揃っている
- **THEN** backend Pod は正常に起動しコンテナが Running になる

#### Scenario: 新規キーが欠落していると backend Pod が起動しない
- **WHEN** `GOOGLE_OAUTH_CLIENT_SECRET` または `GOOGLE_TOKEN_ENC_KEY` が `calendarrabbit-secret` に存在しない
- **THEN** backend Pod は `CreateContainerConfigError` となり起動しない

## REMOVED Requirements

### Requirement: Helm チャートおよびアプリイメージが 0.2.0 であること

**Reason**: チャートを `1.0.2`・アプリイメージを `1.0.0` に更新するため、`0.2.0` 固定の要件を新要件「Helm チャートが 1.0.2・アプリイメージが 1.0.0 であること」に置き換える。
**Migration**: `kustomization.yaml` の `helmCharts[].version` を `0.2.0` → `1.0.2`、`values.yaml` の frontend/backend image tag を `0.2.0` → `1.0.0` に更新する。
