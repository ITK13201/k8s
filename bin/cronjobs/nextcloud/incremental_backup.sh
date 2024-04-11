#!/bin/bash

set -u -o pipefail

now=$(TZ="Asia/Tokyo" date --iso-8601=seconds)

TARGET_DIR="/mnt/hdd/data/k8s/pv/nextcloud"
FULL_BACKUP_BASE_DIR=/mnt/hdd-backup/backups/k8s/pv/nextcloud/full
LATEST_FULL_BACKUP_DIR=$(find ${FULL_BACKUP_BASE_DIR} -mindepth 1 -maxdepth 1 -type d | sort -n | tail -n 1)
INCREMENTAL_BACKUP_DIR="/mnt/hdd-backup/backups/k8s/pv/nextcloud/incremental/${now}"

# ===

### START ###
discord-bot-cli -c "nextcloud" -t "Incremental backup" -d "Incremental backup started." -l "info"

### INCREMENTAL BACKUP ###
discord-bot-cli -c "nextcloud" -t "Incremental backup" -d "Taking a incremental backup..." -l "info"
mkdir -p "${INCREMENTAL_BACKUP_DIR}"
message=$(rsync -a --delete --link-dest="${LATEST_FULL_BACKUP_DIR}"/ ${TARGET_DIR}/ "${INCREMENTAL_BACKUP_DIR}"/ 2>&1 | tee /dev/stdout)
status=$?
if [[ ${status} = 0 ]]; then
    echo "Incremental backup completed."
    discord-bot-cli -c "nextcloud" -t "Incremental backup" -d "Incremental backup completed. Saved to ${INCREMENTAL_BACKUP_DIR}." -l "success"
else
    echo "Incremental backup failed."
    CODE_BLOCK_SEPARATOR="\`\`\`"
    discord-bot-cli -c "nextcloud" -t "Incremental backup" -d "Failed.${CODE_BLOCK_SEPARATOR}${message}${CODE_BLOCK_SEPARATOR}" -l "error"
    exit 1
fi

exit 0
