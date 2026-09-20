## Why

CalendarRabbit の Helm チャートおよびアプリ（frontend/backend）バージョン `0.2.0` が OCI レジストリ `oci://ghcr.io/itk13201` に公開された。
0.2.0 は **LLM プロバイダ選択機能**（DeepSeek を既定とし Claude へ切り戻し可能）と、DeepSeek 経路での **web 検索（Tavily）による事前検索**を追加した重要アップデートであり、現行デプロイ（chart `0.1.3` / app image `0.0.1` / Claude 固定）を追随させる必要がある。

## What Changes

- kustomize の `helmCharts` で参照するチャートバージョンを `0.1.3` → `0.2.0` に更新する。
- `values.yaml` の frontend/backend image tag を `0.0.1` → `0.2.0` に更新する。
- 本番の LLM プロバイダとしてチャート既定の **DeepSeek** を採用する（`backend.env.llmProvider: deepseek`）。DeepSeek モデル・BaseURL・検索プロバイダ（Tavily）・検索結果件数は必要に応じて `values.yaml` に明示する。
- backend が `secretKeyRef`（`optional` 指定なし）で常に参照する新規シークレットキー **`DEEPSEEK_API_KEY`・`SEARCH_API_KEY`** を `ExternalSecret`（`calendarrabbit-secret`）に追加し、1Password アイテムに実値を登録する。これらが欠落すると backend Pod が `CreateContainerConfigError` で起動しないため必須。
- **BREAKING（運用）**: 0.2.0 の backend は起動時に `DEEPSEEK_API_KEY`・`SEARCH_API_KEY` の存在を要求する。シークレット追加と 1Password への値登録を先に完了させないと Pod が起動しない。

## Capabilities

### New Capabilities
- なし（新規アプリではなく既存 CalendarRabbit デプロイの機能追加・バージョン追随）

### Modified Capabilities
- `apps/calendarrabbit`: backend が複数の LLM プロバイダ（DeepSeek 既定 / Claude）を選択可能になり、DeepSeek 経路で web 検索（Tavily）を利用する。これに伴いシークレット要件へ `DEEPSEEK_API_KEY`・`SEARCH_API_KEY` を追加し、Helm チャート／アプリイメージのバージョンを 0.2.0 とする。

## Impact

- `manifests/calendarrabbit/kustomization.yaml`（helmCharts version）
- `manifests/calendarrabbit/values.yaml`（image tag、backend.env の LLM プロバイダ設定）
- `manifests/calendarrabbit/external-secret.yaml`（backend ExternalSecret に 2 キー追加）
- 1Password アイテム `calendarrabbit-secret`（`DEEPSEEK_API_KEY`・`SEARCH_API_KEY` フィールド追加・実値登録は半手動）
- `docs/design/calendarrabbit.md`（バージョン・シークレット・LLM プロバイダ記述の更新）
- 外部依存: DeepSeek API、Tavily 検索 API（新規の外部呼び出し先）
- ArgoCD による `master` への push 後の自動同期対象
