---
# discord-bot-cli 設定（gitignore 対象）
# このファイルをもとに `op inject` で secret.yml を生成すること
# op inject -i ansible/inventory/group_vars/workers/secret.yml.tpl \
#           -o ansible/inventory/group_vars/workers/secret.yml

server_setup_discord_bot_cli_config_token: "{{ op://K8s-Secrets/ansible-workers-secret/token }}"
server_setup_discord_bot_cli_config_channels:
  - name: system
    id: "{{ op://K8s-Secrets/ansible-workers-secret/channel_system_id }}"
  - name: nextcloud
    id: "{{ op://K8s-Secrets/ansible-workers-secret/channel_nextcloud_id }}"
  - name: growi
    id: "{{ op://K8s-Secrets/ansible-workers-secret/channel_growi_id }}"
