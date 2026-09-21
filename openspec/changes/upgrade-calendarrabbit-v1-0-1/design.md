## Context

現行の CalendarRabbit デプロイ（`manifests/calendarrabbit/`）は以下の状態:

- `kustomization.yaml`: `helmCharts` で chart version `0.2.0` を参照。
- `values.yaml`: frontend/backend image tag `0.2.0`、`backend.env.llmProvider: deepseek`、`secret.existingSecret: calendarrabbit-secret`。
- `external-secret.yaml`: `calendarrabbit-secret` が 4 キー（`DB_PASSWORD`・`CLAUDE_API_KEY`・`DEEPSEEK_API_KEY`・`SEARCH_API_KEY`）を 1Password から同期済み。

事前調査で `1.0.2` チャートを取得し `0.2.0` と比較した結果:

- **`appVersion` は `1.0.0`**（chart version は `1.0.2`）。GHCR に `calendarrabbit-{backend,frontend}:1.0.0` は存在するが `:1.0.2` は **404**。よって image tag は `1.0.0` を用いる。
- backend テンプレートに **Google Calendar 連携**が追加。非機密 env `GOOGLE_OAUTH_CLIENT_ID`・`GOOGLE_OAUTH_REDIRECT_URL`（`value:` 直書き）と、機密 env `GOOGLE_OAUTH_CLIENT_SECRET`・`GOOGLE_TOKEN_ENC_KEY`（`secretKeyRef`・`optional` 指定なし）が増える。
- `existingSecret: calendarrabbit-secret` 利用時、backend は 6 キー（既存 4 + Google 2）を `secretKeyRef` で参照する（レンダリングで確認済み）。チャート独自の backend Secret は生成されない。

制約: `master` push は ArgoCD が prune 有効で自動同期する。1Password の値投入・検証は半手動。アクセスは Tailscale Ingress（MagicDNS `calendarrabbit.<tailnet>.ts.net`）限定。動機は proposal.md - Why を参照。

## Goals / Non-Goals

**Goals:**
- チャート `1.0.2` / app image `1.0.0` へ安全な順序（シークレット先行）で追随する。
- Google Calendar 連携を有効化し、抽出した予定を Google Calendar に登録可能にする。
- backend Pod が新規シークレットキー欠落で起動失敗しないことを保証する。

**Non-Goals:**
- LLM プロバイダ／検索プロバイダ設定の変更（DeepSeek 既定・Tavily を維持）。
- mysql・PV 構成の変更。
- Google Calendar 連携のアプリ内 UI/挙動の設計（アプリ側の責務）。

## Decisions

### D1: image tag は `appVersion` 準拠で `1.0.0` を用いる

chart version は `1.0.2` だが `appVersion` は `1.0.0` で、`1.0.2` のアプリイメージは未発行（GHCR 404）。よって `kustomization.yaml` の `helmCharts[].version` は `1.0.2`、`values.yaml` の image tag は `1.0.0` とする。両者のバージョンが一致しないことを docs にも明記する。

代替案: image tag も `1.0.2` にする → イメージが存在せず `ImagePullBackOff` になるため不採用。

### D2: シークレット追加を先行し、その後にバージョンを上げる

`GOOGLE_OAUTH_CLIENT_SECRET`・`GOOGLE_TOKEN_ENC_KEY` は `optional` なしの `secretKeyRef` のため、これらが `calendarrabbit-secret` に存在しないまま `1.0.2` の backend をデプロイすると Pod が `CreateContainerConfigError` で起動しない（0.2.0 追随時と同じ制約）。よって以下の順序で進める:

1. Google Cloud で OAuth クライアントを作成し client ID / secret / リダイレクト URI を確定。
2. `external-secret.yaml` に 2 キーを追加し、1Password アイテムに実値を登録（半手動）→ Secret 同期を確認。
3. その後に `kustomization.yaml`（chart 1.0.2）と `values.yaml`（image tag 1.0.0・Google env）を更新。

代替案: 全部を一度に push → ArgoCD が Secret 同期前に Deployment を更新し一時的に Pod 起動失敗するリスクがあるため不採用。

### D3: 機密／非機密の切り分け

チャートは `googleOAuthClientID`・`googleOAuthRedirectURL` を `value:` 直書きの非機密 env として、`GOOGLE_OAUTH_CLIENT_SECRET`・`GOOGLE_TOKEN_ENC_KEY` を `secretKeyRef` の機密として扱う。これに従い:

- 非機密（`values.yaml` にコミット）: `backend.env.googleOAuthClientID`・`backend.env.googleOAuthRedirectURL`。OAuth クライアント ID はブラウザにも渡る公開情報のためコミット可。
- 機密（1Password → ExternalSecret、非コミット）: `GOOGLE_OAUTH_CLIENT_SECRET`・`GOOGLE_TOKEN_ENC_KEY`。`GOOGLE_TOKEN_ENC_KEY` は OAuth トークン暗号化鍵で、アプリ要件に合う長さの乱数（既定想定: 32 byte）を生成する。実際の必要形式は apply 時に app（`/swagger` 等）で確認する。

### D4: リダイレクト URL（tailnet FQDN）のコミットは GitOps 上不可避

`googleOAuthRedirectURL` は backend が OAuth コールバックを構成するために必要で、チャートは `value:` 直書きの非機密 env として扱う。ArgoCD (GitOps) では values.yaml にコミットされた値のみが反映されるため、リダイレクト URL（`https://calendarrabbit.<tailnet>.ts.net/...` 形式）を values.yaml にコミットする必要がある。docs が tailnet 名を `<tailnet>` プレースホルダで扱う方針（[[feedback_no_personal_info_in_repo]]）と一部緊張するが、GitOps 上コミットは不可避。apply 時に実 FQDN のコミット可否をユーザーが最終確認する。

コールバックのパス（`/api/.../google/callback` 等）は app 依存のため、apply 時に `/swagger` またはアプリ仕様で確定してから Google Cloud のリダイレクト URI と values を合わせる。

## Risks / Trade-offs

- [新規キー欠落で backend 起動失敗] → D2 の順序（シークレット先行 + 同期確認）で回避。apply 時に `kubectl get secret calendarrabbit-secret -o jsonpath` で 6 キーの存在を確認する。
- [image tag 誤り（1.0.2 指定）で ImagePullBackOff] → D1 で image tag を `1.0.0` に固定。
- [リダイレクト URI 不一致で OAuth 失敗] → Google Cloud 側の登録 URI・`googleOAuthRedirectURL`・実際の backend コールバックパスの 3 者を一致させる。パスは apply 時に確定。
- [Google Calendar API への新規外部通信] → backend からのアウトバウンド通信が新たに発生。VPN 前提の内部アプリだが外部 API 呼び出しは許可されている前提。
- [tailnet FQDN のコミット] → D4 参照。apply 時にユーザー確認。
- [ArgoCD prune による意図しない削除] → 追加のみで既存リソース構成は変えないため影響なし。

## Migration Plan

1. Google Cloud で OAuth 2.0 クライアントを作成し、client ID / secret を取得、リダイレクト URI を登録。
2. `external-secret.yaml` に `GOOGLE_OAUTH_CLIENT_SECRET`・`GOOGLE_TOKEN_ENC_KEY` を追加（雛形作成）。
3. 1Password アイテム `calendarrabbit-secret` に 2 フィールドを追加し実値を登録（半手動・ユーザー）。
4. push → ESO が Secret を同期。`kubectl get secret calendarrabbit-secret` で 6 キーを確認。
5. `kustomization.yaml` を chart `1.0.2`、`values.yaml` を image tag `1.0.0` + `backend.env.googleOAuthClientID`・`googleOAuthRedirectURL` に更新。
6. `kustomize build --enable-helm manifests/calendarrabbit/` でローカルレンダリング検証 → `yamlfmt .`。
7. push → ArgoCD 同期 → backend/frontend Pod が Running、Google Calendar への予定登録が動作することを確認。
8. `docs/design/calendarrabbit.md` を更新。

**ロールバック**: `kustomization.yaml` の version を `0.2.0`、`values.yaml` の image tag を `0.2.0` に戻し、Google env を削除して push。Secret に追加したキーは残しても無害。
