#!/bin/bash

set -u -o pipefail

now=$(TZ="Asia/Tokyo" date --iso-8601=seconds)

TARGET_DIR="/mnt/hdd/data/k8s/pv/nextcloud"
FULL_BACKUP_DIR="/mnt/hdd-backup/backups/k8s/pv/nextcloud/full/${now}"

# ===

### START ###
discord-bot-cli -c "nextcloud" -t "Full backup" -d "Full backup started." -l "info"

### FULL BACKUP ###
discord-bot-cli -c "nextcloud" -t "Full backup" -d "Taking a full backup..." -l "info"
mkdir -p "${FULL_BACKUP_DIR}"
message=$(rsync -a --delete ${TARGET_DIR}/ "${FULL_BACKUP_DIR}"/ 2>&1 | tee /dev/stdout)
status=$?
if [[ ${status} = 0 ]]; then
    echo "Full backup completed."
    discord-bot-cli -c "nextcloud" -t "Full backup" -d "Full backup completed. Saved to ${FULL_BACKUP_DIR}." -l "success"
else
    echo "Full backup failed."
    CODE_BLOCK_SEPARATOR="\`\`\`"
    discord-bot-cli -c "nextcloud" -t "Backup" -d "Failed.${CODE_BLOCK_SEPARATOR}${message}${CODE_BLOCK_SEPARATOR}" -l "error"
    exit 1
fi

exit 0
