# CLAUDE.md — ansible/

Ansible による Kubernetes クラスタ構築・設定管理。

詳細は [docs/ansible.md](../docs/ansible.md) および [docs/design/ansible.md](../docs/design/ansible.md) を参照。

## コマンド

**`ansible/` ディレクトリから実行すること**（`ansible.cfg` の相対パス設定のため）。

```bash
cd ansible/
ansible-galaxy collection install -r requirements.yml
ansible all -m ping                              # 接続確認
ansible-playbook playbooks/site.yml              # 全ノード
ansible-playbook playbooks/workers.yml           # ワーカーのみ
ansible-playbook playbooks/site.yml --check      # dry-run
ansible-lint roles/<role>/tasks/main.yml         # lint
```

## ロール変数命名規則

- ロール変数には必ずロール名プレフィックスを付ける: `rolename_varname`
- ロール内部変数（`register` など）はダブルアンダースコア: `rolename__varname`
- `ansible-lint` で検証すること

## シークレット管理

- `inventory/group_vars/workers/secret.yml` に機密変数を記載（gitignore 対象）
- テンプレートは `inventory/group_vars/workers/secret.yml.example` を参照
