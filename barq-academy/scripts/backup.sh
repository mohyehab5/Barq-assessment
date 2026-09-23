#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/postgres_backup_${TIMESTAMP}.sql"

mkdir -p "$BACKUP_DIR"

echo "==> Triggering PostgreSQL database dump..."
docker exec postgres pg_dump -U barq_app -d barq_tasks > "$BACKUP_FILE"

if [ -s "$BACKUP_FILE" ]; then
  echo "PASS: PostgreSQL backup created successfully at ${BACKUP_FILE} (Size: $(du -h "$BACKUP_FILE" | cut -f1))"
else
  echo "FAIL: Backup file is empty or was not generated."
  exit 1
fi
