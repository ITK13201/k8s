#!/bin/bash

now=$(TZ="Asia/Tokyo" date --iso-8601=seconds)

CURRENT_DIR="/mnt/hdd/data/k8s/pv"
TARGET_DIR_NAME="nextcloud"
OUTPUT_DIR="/mnt/hdd-backup/backups/k8s/pv/nextcloud"
OUTPUT_FILE_NAME="nextcloud-backup-${now}.bz2"

backup () {
    tar cjvfp "${OUTPUT_DIR}/${OUTPUT_FILE_NAME}" -C ${CURRENT_DIR} ${TARGET_DIR_NAME}
}

if backup; then
    echo "Backup completed."
else
    echo "Backup failed."
fi
