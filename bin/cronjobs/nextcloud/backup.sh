#!/bin/bash

set -u -o pipefail

now=$(TZ="Asia/Tokyo" date --iso-8601=seconds)

CURRENT_DIR="/mnt/hdd/data/k8s/pv"
TARGET_DIR_NAME="nextcloud"
OUTPUT_DIR="/mnt/hdd-backup/backups/k8s/pv/nextcloud"
OUTPUT_FILE_NAME="nextcloud-backup-${now}.bz2"

MESSAGE=$(tar cjvfp "${OUTPUT_DIR}/${OUTPUT_FILE_NAME}" -C ${CURRENT_DIR} ${TARGET_DIR_NAME} |& tee /dev/tty)
status=$?
if [[ ${status} = 0 ]]; then
    echo "Backup completed."
    discord-bot-cli -c "${CHANNEL_ID}" -t "Backup" -d "completed. saved to ${OUTPUT_FILE_NAME}." -l "info"
else
    echo "Backup failed."
    CODE_BLOCK_SEPARATOR="\`\`\`"
    discord-bot-cli -c "${CHANNEL_ID}" -t "Backup" -d "failed.${CODE_BLOCK_SEPARATOR}${MESSAGE}${CODE_BLOCK_SEPARATOR}" -l "error"
fi

exit ${status}
