#!/bin/sh

set -eu

# Set Versions
GROWI_BACKUP_TOOL_VERSION=0.1.0

# Set environment variables
TIMESTAMP=$(date +%Y%m%d%H%M%S)
BACKUP_DIR=/backup/${TIMESTAMP}
BACKUP_DUMP_DIR=/backup/${TIMESTAMP}/dump
BACKUP_EXPORT_DIR=/backup/${TIMESTAMP}/export
BACKUP_EXPAND_DIR=/backup/${TIMESTAMP}/expand
ATTACHMENTS_DIR=/attachments
BACKUP_TARBALL_PATH=/backup/${TIMESTAMP}.tar.bz2

echo "[$(date -Iseconds)] Started backup."

# Install required packages
echo "[$(date -Iseconds)] Installing required packages..."

apt-get update
apt-get install -y curl bzip2

curl -OL https://github.com/ITK13201/growi-backup-tool/releases/download/v${GROWI_BACKUP_TOOL_VERSION}/growi-backup-tool_${GROWI_BACKUP_TOOL_VERSION}_linux_amd64.tar.gz
tar -C /usr/local/bin -xzf growi-backup-tool_${GROWI_BACKUP_TOOL_VERSION}_linux_amd64.tar.gz
chmod +x /usr/local/bin/growi-backup-tool
rm -f growi-backup-tool_${GROWI_BACKUP_TOOL_VERSION}_linux_amd64.tar.gz

echo "[$(date -Iseconds)] Installed required packages."

# Create backup directories
echo "[$(date -I"seconds")] Creating backup directories..."
mkdir -p "${BACKUP_DIR}"
mkdir -p "${BACKUP_DUMP_DIR}"
mkdir -p "${BACKUP_EXPORT_DIR}"
mkdir -p "${BACKUP_EXPAND_DIR}"
echo "[$(date -Iseconds)] Created backup directories."


# Backup MongoDB
echo "[$(date -Iseconds)] Creating MongoDB backup..."
mongodump \
    --uri="${MONGO_URI}" \
    --out="${BACKUP_DUMP_DIR}"
echo "[$(date -Iseconds)] Created MongoDB backup."

# Export MongoDB
echo "[$(date -Iseconds)] Exporting MongoDB..."
mongoexport \
    --uri="${MONGO_URI}" \
    --collection=pages \
    --out="${BACKUP_EXPORT_DIR}"/pages.jsonl
mongoexport \
    --uri="${MONGO_URI}" \
    --collection=revisions \
    --out="${BACKUP_EXPORT_DIR}"/revisions.jsonl
mongoexport \
    --uri="${MONGO_URI}" \
    --collection=attachments \
    --out="${BACKUP_EXPORT_DIR}"/attachments.jsonl
echo "[$(date -Iseconds)] Exported MongoDB."


# Expand exprorted json files to markdown files
echo "[$(date -Iseconds)] Expanding exported json files to markdown files..."
/usr/local/bin/growi-backup-tool expand -p "${BACKUP_EXPORT_DIR}"/pages.jsonl -r "${BACKUP_EXPORT_DIR}"/revisions.jsonl -o "${BACKUP_EXPAND_DIR}"
echo "[$(date -Iseconds)] Expanded exported json files to markdown files."

# Copy attachments
echo "[$(date -Iseconds)] Copying attachments..."
cp -r ${ATTACHMENTS_DIR} "${BACKUP_DIR}"
echo "[$(date -Iseconds)] Copied attachments."

# Create tarball (*.tar.bz2)
echo "[$(date -Iseconds)] Creating tarball..."
tar cjf "${BACKUP_TARBALL_PATH}" -C /backup "${TIMESTAMP}"
echo "[$(date -Iseconds)] Created tarball."


# Clean up
echo "[$(date -Iseconds)] Cleaning up..."
rm -rf "${BACKUP_DIR}"
echo "[$(date -Iseconds)] Cleaned up."
