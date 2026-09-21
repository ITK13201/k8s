## Why

CalendarRabbit の Helm チャートバージョン `1.0.2` が OCI レジストリ `oci://ghcr.io/itk13201` に公開された。
`1.0.2` は **Google Calendar 連携**（OAuth によるカレンダー登録）を追加した重要アップデートであり、現行デプロイ（chart `0.2.0` / app image `0.2.0`）を追随させたうえで連携を有効化する。
なお `1.0.2` チャートの `appVersion` は `1.0.0` で、frontend/backend のアプリイメージは `1.0.0`（`1.0.2` イメージは未発行）。

## What Changes

- kustomize の `helmCharts` で参照するチャートバージョンを `0.2.0` → `1.0.2` に更新する。
- `values.yaml` の frontend/backend image tag を `0.2.0` → **`1.0.0`**（`appVersion` 準拠、`1.0.2` イメージは存在しない）に更新する。
- **Google Calendar 連携を有効化する**。`1.0.2` の backend は次の env とシークレットキーを新たに要求する:
  - 非機密 env（`values.yaml` の `backend.env` に設定）: `googleOAuthClientID`・`googleOAuthRedirectURL`
  - 機密キー（`ExternalSecret` / 1Password 経由）: `GOOGLE_OAUTH_CLIENT_SECRET`・`GOOGLE_TOKEN_ENC_KEY`
- backend が `secretKeyRef`（`optional` 指定なし）で常に参照する新規シークレットキー **`GOOGLE_OAUTH_CLIENT_SECRET`・`GOOGLE_TOKEN_ENC_KEY`** を `ExternalSecret`（`calendarrabbit-secret`）に追加し、1Password アイテムに実値を登録する。
- Google Cloud に OAuth 2.0 クライアントを作成し、リダイレクト URI を登録する（外部設定）。
- **BREAKING（運用）**: `1.0.2` の backend は起動時に `GOOGLE_OAUTH_CLIENT_SECRET`・`GOOGLE_TOKEN_ENC_KEY` の存在を要求する。シークレット追加と 1Password への値登録を先に完了させないと backend Pod が `CreateContainerConfigError` で起動しない。既存の LLM/検索構成（DeepSeek 既定 + Tavily・4 キー）は変更なし。

## Capabilities

### New Capabilities
- なし（既存 CalendarRabbit デプロイへの機能追加・バージョン追随）

### Modified Capabilities
- `apps/calendarrabbit`: backend が Google Calendar 連携（OAuth）をサポートする。これに伴いシークレット要件へ `GOOGLE_OAUTH_CLIENT_SECRET`・`GOOGLE_TOKEN_ENC_KEY` を追加し、非機密 env に `googleOAuthClientID`・`googleOAuthRedirectURL` を追加する。Helm チャートを `1.0.2`、アプリイメージを `1.0.0` とする。

## Impact

- `manifests/calendarrabbit/kustomization.yaml`（helmCharts version → `1.0.2`）
- `manifests/calendarrabbit/values.yaml`（image tag → `1.0.0`、`backend.env` に Google OAuth の非機密設定を追加）
- `manifests/calendarrabbit/external-secret.yaml`（backend ExternalSecret に 2 キー追加）
- 1Password アイテム `calendarrabbit-secret`（`GOOGLE_OAUTH_CLIENT_SECRET`・`GOOGLE_TOKEN_ENC_KEY` フィールド追加・実値登録は半手動）
- Google Cloud OAuth 2.0 クライアント（新規作成・リダイレクト URI 登録）
- `docs/design/calendarrabbit.md`（バージョン・シークレット・Google Calendar 連携記述の更新）
- 外部依存: Google OAuth / Google Calendar API（新規の外部呼び出し先）
- ArgoCD による `master` への push 後の自動同期対象
