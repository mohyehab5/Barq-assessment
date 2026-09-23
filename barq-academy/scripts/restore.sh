#!/usr/bin/env bash
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <path_to_backup_sql_file>"
  exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
  echo "FAIL: Backup file $BACKUP_FILE does not exist."
  exit 1
fi

echo "==> Restoring PostgreSQL database from ${BACKUP_FILE}..."
docker exec -i postgres psql -U barq_app -d barq_tasks < "$BACKUP_FILE"
echo "PASS: Database restored successfully."
