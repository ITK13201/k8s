## Context

現行の CalendarRabbit デプロイ（`manifests/calendarrabbit/`）は以下の状態:

- `kustomization.yaml`: `helmCharts` で `oci://ghcr.io/itk13201` の chart version `0.1.3` を参照。
- `values.yaml`: frontend/backend image tag `0.0.1`、backend は Claude 固定（`existingSecret: calendarrabbit-secret`）。
- `external-secret.yaml`: `calendarrabbit-secret`（ESO/ClusterSecretStore `onepassword`）が `CLAUDE_API_KEY`・`DB_PASSWORD` を 1Password から同期。

0.2.0 チャート（`helm show` / template で確認済み）の backend Deployment は、`backend.secret.existingSecret` 指定時に次の 4 キーを **`optional` 指定なしの `secretKeyRef`** で参照する: `DB_PASSWORD`・`CLAUDE_API_KEY`・`DEEPSEEK_API_KEY`・`SEARCH_API_KEY`。加えて env として `LLM_PROVIDER`・`DEEPSEEK_MODEL`・`DEEPSEEK_BASE_URL`・`SEARCH_PROVIDER`・`SEARCH_MAX_RESULTS` を values から注入する。チャート既定は `llmProvider: deepseek`。

制約: `master` push は ArgoCD が prune 有効で自動同期する。1Password の値投入・検証は半手動（Claude はアイテム/フィールドの雛形作成まで）。動機は proposal.md - Why を参照。

## Goals / Non-Goals

**Goals:**
- チャート `0.2.0` / app image `0.2.0` への追随を安全な順序（シークレット先行）で行う。
- 本番 LLM プロバイダとして DeepSeek 既定を採用し、切り戻し可能な構成を values で明示する。
- backend Pod が新規シークレットキー欠落で起動失敗しないことを保証する。

**Non-Goals:**
- frontend/mysql の挙動変更（イメージ tag 更新以外）。
- LLM プロバイダの実行時自動フェイルオーバー（本 chart は静的な `LLM_PROVIDER` 選択のみ）。
- リソース requests/limits のチューニング（チャート既定を踏襲）。

## Decisions

### D1: シークレット追加を先行し、その後にバージョンを上げる

`DEEPSEEK_API_KEY`・`SEARCH_API_KEY` は `optional` なしの `secretKeyRef` のため、これらが `calendarrabbit-secret` に存在しないまま 0.2.0 の backend をデプロイすると Pod が `CreateContainerConfigError` で起動しない。よって以下の順序で進める:

1. `external-secret.yaml` に 2 キーを追加し、1Password アイテムに実値を登録（半手動）→ Secret 同期を確認。
2. その後に `kustomization.yaml`（chart 0.2.0）と `values.yaml`（image tag 0.2.0・LLM プロバイダ設定）を更新。

代替案: 全部を一度に push → ArgoCD が Secret 同期前に Deployment を更新し、一時的に Pod 起動失敗するリスクがあるため不採用。

### D2: LLM プロバイダは DeepSeek 既定を values に明示

プロバイダ選択のみを固定するため `values.yaml` に `backend.env.llmProvider: deepseek` を明示する。`deepseekModel`（`deepseek-v4-pro`）・`deepseekBaseURL`（`https://api.deepseek.com`）・`searchProvider`（`tavily`）・`searchMaxResults`（`10`）はチャート既定に委ね、values には書かない（チャート作者が app 0.2.0 に合わせて設定した既定を尊重し、values を最小に保つ）。Claude への切り戻しは `llmProvider: claude` の 1 行変更で可能。DeepSeek API キー・Tavily 検索キーは入手済みのため、1Password への値登録後すぐに移行できる。

### D3: 1Password キー名は chart の secretKeyRef と一致させる

Secret 内のキー名は chart が参照する `DEEPSEEK_API_KEY`・`SEARCH_API_KEY` に厳密一致させる。ExternalSecret の `secretKey` と 1Password `property` を同名で定義する（既存の `CLAUDE_API_KEY`・`DB_PASSWORD` と同方式）。

## Risks / Trade-offs

- [新規キー欠落で backend 起動失敗] → D1 の順序（シークレット先行 + 同期確認）で回避。apply 時に `kubectl get secret calendarrabbit-secret -o jsonpath` で 4 キーの存在を確認する。
- [DeepSeek/Tavily の実 API キー未取得] → 値登録は半手動。キー未取得だと予定抽出が失敗するため、値登録完了を前提にバージョンを上げる。取得できない場合は D2 の切り戻し（`llmProvider: claude`）を選択肢として残す。
- [DeepSeek/Tavily への新規外部通信] → backend からインターネットへのアウトバウンド通信が新たに発生する。VPN 前提の内部アプリだが、外部 API 呼び出し自体は許可されている前提。
- [ArgoCD prune による意図しない削除] → 追加のみで既存リソース構成は変えないため影響なし。

## Migration Plan

1. `external-secret.yaml` に `DEEPSEEK_API_KEY`・`SEARCH_API_KEY` を追加（雛形作成）。
2. 1Password アイテム `calendarrabbit-secret` に 2 フィールドを追加し実値を登録（半手動・ユーザー）。
3. push → ESO が Secret を同期。`kubectl get secret calendarrabbit-secret` で 4 キーを確認。
4. `kustomization.yaml` を chart `0.2.0`、`values.yaml` を image tag `0.2.0` + `backend.env.llmProvider: deepseek` 等に更新。
5. `kustomize build --enable-helm manifests/calendarrabbit/` でローカルレンダリング検証 → `yamlfmt .`。
6. push → ArgoCD 同期 → backend/frontend Pod が Running、予定抽出が DeepSeek 経路で動作することを確認。
7. `docs/design/calendarrabbit.md` を更新。

**ロールバック**: `kustomization.yaml` の version と `values.yaml` の tag を `0.1.3`/`0.0.1`、`llmProvider` 未指定（または `claude`）に戻して push。Secret に追加したキーは残しても無害。
