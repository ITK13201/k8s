## 1. Google Cloud OAuth クライアント準備

- [ ] 1.1 backend の Google OAuth コールバックパスを `/swagger` またはアプリ仕様で確認し、リダイレクト URI（`https://calendarrabbit.<tailnet>.ts.net/<callback-path>`）を確定する
- [ ] 1.2 Google Cloud で OAuth 2.0 クライアントを作成し、client ID・client secret を取得、1.1 のリダイレクト URI を承認済みリダイレクト URI に登録する（Google Calendar API を有効化）

## 2. シークレット追加（バージョン更新より先行）

- [x] 2.1 `manifests/calendarrabbit/external-secret.yaml` の `calendarrabbit-secret` ExternalSecret に `GOOGLE_OAUTH_CLIENT_SECRET`・`GOOGLE_TOKEN_ENC_KEY` の `data` エントリ（`secretKey` / `remoteRef.property` を同名）を追加し、`yamlfmt .` が差分なしで通ることを確認する
- [ ] 2.2 1Password アイテム `calendarrabbit-secret` に `GOOGLE_OAUTH_CLIENT_SECRET`・`GOOGLE_TOKEN_ENC_KEY` フィールドの雛形を作成する（`GOOGLE_TOKEN_ENC_KEY` はアプリ要件に合う長さの乱数。実値の投入・検証はユーザーが半手動で実施）
- [ ] 2.3 push 後、`kubectl get secret calendarrabbit-secret -n calendarrabbit -o jsonpath='{.data}'` に 6 キー（`DB_PASSWORD`・`CLAUDE_API_KEY`・`DEEPSEEK_API_KEY`・`SEARCH_API_KEY`・`GOOGLE_OAUTH_CLIENT_SECRET`・`GOOGLE_TOKEN_ENC_KEY`）が揃っていることを確認する

## 3. チャート・アプリのバージョン更新と Google env 設定

- [x] 3.1 `manifests/calendarrabbit/kustomization.yaml` の `helmCharts[].version` を `0.2.0` → `1.0.2` に更新する
- [x] 3.2 `manifests/calendarrabbit/values.yaml` の `frontend.image.tag`・`backend.image.tag` を `0.2.0` → `1.0.0`（`appVersion` 準拠）に更新する
- [ ] 3.3 `manifests/calendarrabbit/values.yaml` の `backend.env` に `googleOAuthClientID`（1.2 で取得した client ID）・`googleOAuthRedirectURL`（1.1 で確定したリダイレクト URI）を追加する。tailnet FQDN を含むリダイレクト URI をコミットしてよいかユーザーに最終確認する

## 4. ローカル検証

- [ ] 4.1 `kustomize build --enable-helm manifests/calendarrabbit/` を実行し、chart `1.0.2`・backend/frontend image tag `1.0.0` の Deployment がエラーなくレンダリングされ、backend env に `GOOGLE_OAUTH_CLIENT_ID`・`GOOGLE_OAUTH_REDIRECT_URL` と 6 つの `secretKeyRef`（既存 4 + Google 2）が含まれることを確認する
- [ ] 4.2 `yamlfmt .` を実行し、変更ファイルがフォーマット済み（差分なし）であることを確認する

## 5. デプロイと確認

- [ ] 5.1 コミット（1 行目英語・本文日本語）して `master` に push し、ArgoCD の同期完了を確認する
- [ ] 5.2 push 後、`kubectl get pods -n calendarrabbit` で backend/frontend Pod が Running になり、`CreateContainerConfigError`・`ImagePullBackOff` が発生していないことを確認する
- [ ] 5.3 Tailscale VPN 接続端末で Google Calendar 連携の OAuth フローを実行し、抽出した予定が Google Calendar に登録できることを確認する

## 6. ドキュメント更新

- [x] 6.1 `docs/design/calendarrabbit.md` のチャートバージョン（`1.0.2`）・image tag（`1.0.0`・appVersion との不一致）・シークレットキー一覧（6 キー）・Google Calendar 連携の記述を更新する
