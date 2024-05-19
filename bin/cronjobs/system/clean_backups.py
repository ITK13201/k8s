#!/usr/bin/env python3

import datetime
import logging
import os
import subprocess

APPLICATIONS = [
    "nextcloud",
    "growi",
]

logger = logging.getLogger(__name__)


def log_and_send_to_discord(channel: str, title: str, description: str, level: str):
    log_message = "<{}> {}: {}".format(channel, title, description)
    if level == "info":
        logger.info(log_message)
    elif level == "warning":
        logger.warning(log_message)
    elif level == "error":
        logger.error(log_message)
    else:
        logger.info(log_message)

    # Send to Discord
    return_code = subprocess.call(
        [
            "discord-bot-cli",
            "-c",
            channel,
            "-t",
            title,
            "-d",
            description,
            "-l",
            level,
        ]
    )
    if return_code == 0:
        logger.info("Sent to Discord")
    else:
        logger.error("Failed to send to Discord")


def clean_backups(app_name: str):
    incremental_backup_dir = "/mnt/hdd-backup/backups/k8s/pv/{}/incremental".format(
        app_name
    )
    full_backup_dir = "/mnt/hdd-backup/backups/k8s/pv/{}/full".format(app_name)
    archive_dir = "/mnt/hdd-backup/backups/k8s/pv/{}/archive".format(app_name)

    # Clean incremental backups
    # Keep 1 month of incremental backups
    for file in os.listdir(incremental_backup_dir):
        file_path = os.path.join(incremental_backup_dir, file)
        creation_time = datetime.datetime.fromisoformat(file)
        now = datetime.datetime.now(tz=datetime.timezone("Asia/Tokyo"))
        if (now - creation_time).days > 30:
            os.remove(file_path)
            log_and_send_to_discord(
                app_name,
                "Backup Cleanup",
                "Deleted an old incremental backup: {}".format(file_path),
                "success",
            )

    # Clean full backups & archive
    # Keep 1 month of full backups
    for file in os.listdir(full_backup_dir):
        file_path = os.path.join(full_backup_dir, file)
        creation_time = datetime.datetime.fromisoformat(file)
        now = datetime.datetime.now()
        if (now - creation_time).days > 30:
            # Archive the backup as bz2
            archive_path = os.path.join(archive_dir, f"{file}.tar.bz2")
            log_and_send_to_discord(
                app_name,
                "Backup Cleanup",
                "Archiving an old full backup: {}".format(archive_path),
                "info",
            )
            return_code = subprocess.call(
                "tar -cjfp {} {} -C {}".format(
                    archive_path, file_path, full_backup_dir
                ),
                shell=True,
            )
            log_and_send_to_discord(
                app_name,
                "Backup Cleanup",
                "Archived an old full backup: {}".format(archive_path),
                "success",
            )
            if return_code == 0:
                # Remove the original backup
                os.remove(file_path)
                log_and_send_to_discord(
                    app_name,
                    "Backup Cleanup",
                    "Deleted an old full backup: {}".format(file_path),
                    "success",
                )


def main():
    for app_name in APPLICATIONS:
        log_and_send_to_discord(
            app_name,
            "Backup Cleanup",
            "Starting backup cleanup",
            "info",
        )
        clean_backups(app_name)
        log_and_send_to_discord(
            app_name,
            "Backup Cleanup",
            "Finished backup cleanup",
            "info",
        )


if __name__ == "__main__":
    main()
