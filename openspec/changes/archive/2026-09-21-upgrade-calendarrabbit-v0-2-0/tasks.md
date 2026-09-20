## 1. シークレット追加（バージョン更新より先行）

- [x] 1.1 `manifests/calendarrabbit/external-secret.yaml` の `calendarrabbit-secret` ExternalSecret に `DEEPSEEK_API_KEY`・`SEARCH_API_KEY` の `data` エントリ（`secretKey` / `remoteRef.property` を同名）を追加し、`yamlfmt .` が差分なしで通ることを確認する
- [x] 1.2 1Password アイテム `calendarrabbit-secret` に `DEEPSEEK_API_KEY`・`SEARCH_API_KEY` フィールドの雛形を作成する（実値の投入・検証はユーザーが半手動で実施）
- [x] 1.3 push 後、`kubectl get secret calendarrabbit-secret -n calendarrabbit -o jsonpath='{.data}'` に 4 キー（`DB_PASSWORD`・`CLAUDE_API_KEY`・`DEEPSEEK_API_KEY`・`SEARCH_API_KEY`）が揃っていることを確認する

## 2. チャート・アプリのバージョン更新

- [x] 2.1 `manifests/calendarrabbit/kustomization.yaml` の `helmCharts[].version` を `0.1.3` → `0.2.0` に更新する
- [x] 2.2 `manifests/calendarrabbit/values.yaml` の `frontend.image.tag`・`backend.image.tag` を `0.0.1` → `0.2.0` に更新する
- [x] 2.3 `manifests/calendarrabbit/values.yaml` の `backend.env` に `llmProvider: deepseek` のみを明示する。`deepseekModel`・`deepseekBaseURL`・`searchProvider`・`searchMaxResults` はチャート既定（`deepseek-v4-pro` / `https://api.deepseek.com` / `tavily` / `10`）に委ね、values には書かない

## 3. 検証とドキュメント

- [x] 3.1 `kustomize build --enable-helm manifests/calendarrabbit/` を実行し、chart `0.2.0`・backend/frontend image tag `0.2.0` の Deployment がエラーなくレンダリングされ、backend env に `LLM_PROVIDER=deepseek` と 4 つの `secretKeyRef` が含まれることを確認する
- [x] 3.2 `yamlfmt .` を実行し、変更ファイルがフォーマット済み（差分なし）であることを確認する
- [x] 3.3 push → ArgoCD 同期後、`kubectl get pods -n calendarrabbit` で backend/frontend Pod が Running になり、`CreateContainerConfigError` が発生していないことを確認する
- [ ] 3.4 backend が DeepSeek 経路で予定抽出を行えること（実際の入力で予定登録が成功すること）を確認する
- [x] 3.5 `docs/design/calendarrabbit.md` のチャート/アプリバージョン・シークレットキー一覧・LLM プロバイダ（DeepSeek 既定 + Tavily 検索）に関する記述を更新する
