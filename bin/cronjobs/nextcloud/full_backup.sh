#!/bin/bash

set -u -o pipefail

now=$(TZ="Asia/Tokyo" date --iso-8601=seconds)

TARGET_DIR="/mnt/hdd/data/k8s/pv/nextcloud"
FULL_BACKUP_DIR="/mnt/hdd-backup/backups/k8s/pv/nextcloud/full-backup/nextcloud"
ARCHIVE_TARGET_PARENT_DIR="/mnt/hdd-backup/backups/k8s/pv/nextcloud/full-backup"
ARCHIVE_TARGET_DIR_NAME="nextcloud"
ARCHIVES_DIR="/mnt/hdd-backup/backups/k8s/pv/nextcloud/archives"
ARCHIVE_FILE_NAME="nextcloud-backup-${now}.bz2"

# ===

### START ###
discord-bot-cli -c "nextcloud" -t "Full backup" -d "Full backup started." -l "info"

### FULL BACKUP ###
discord-bot-cli -c "nextcloud" -t "Full backup" -d "Taking a full backup..." -l "info"
message=$(rsync -a --delete ${TARGET_DIR}/ ${FULL_BACKUP_DIR}/)
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

### ARCHIVE ###
discord-bot-cli -c "nextcloud" -t "Full backup" -d "Taking a backup archive..." -l "info"
message=$(tar cjfp "${ARCHIVES_DIR}/${ARCHIVE_FILE_NAME}" -C ${ARCHIVE_TARGET_PARENT_DIR} ${ARCHIVE_TARGET_DIR_NAME} |& tee /dev/tty)
status=$?
if [[ ${status} = 0 ]]; then
    echo "Backup archiving completed."
    discord-bot-cli -c "nextcloud" -t "Full backup" -d "Backup archiving completed. Saved to ${ARCHIVES_DIR}/${ARCHIVE_FILE_NAME}." -l "success"
else
    echo "Backup archiving failed."
    CODE_BLOCK_SEPARATOR="\`\`\`"
    discord-bot-cli -c "nextcloud" -t "Full backup" -d "Backup archiving failed.${CODE_BLOCK_SEPARATOR}${message}${CODE_BLOCK_SEPARATOR}" -l "error"
    exit 1
fi

exit 0
