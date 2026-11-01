#!/usr/bin/env bash
# Runs on the server from /tmp/mylawyer-backend.tar.
# Stops at the first failure, and the database backup always comes first.
set -euo pipefail

APP_DIR="${APP_DIR:-/var/www/mylawyer/backend}"
SERVICE="${SERVICE:-mylawyer-backend}"
RELEASE_DIR="$(mktemp -d)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="/root/mylawyer-backups"

if [ ! -f "$APP_DIR/package.json" ]; then
  echo "Backend folder not found at $APP_DIR. Set APP_DIR and run again."
  exit 1
fi

DATABASE_URL="${DATABASE_URL:-}"
if [ -z "$DATABASE_URL" ] && [ -f "$APP_DIR/.env" ]; then
  DATABASE_URL="$(grep -E '^DATABASE_URL=' "$APP_DIR/.env" | head -1 | cut -d= -f2- | tr -d '"'"'"' \r')"
fi
if [ -z "$DATABASE_URL" ]; then
  echo "DATABASE_URL not found. Export it and run again."
  exit 1
fi

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/mylawyer-$STAMP.sql.gz"
echo "Backing up the database to $BACKUP_FILE"
pg_dump "$DATABASE_URL" | gzip > "$BACKUP_FILE"
if [ "$(gzip -dc "$BACKUP_FILE" | wc -c)" -lt 1000 ]; then
  echo "The backup looks empty. Stopping."
  exit 1
fi

echo "Keeping the current code in $BACKUP_DIR/code-$STAMP.tar.gz"
tar -C "$APP_DIR" --exclude=node_modules --exclude=storage -czf "$BACKUP_DIR/code-$STAMP.tar.gz" .

# The server keeps build output only, so the build happens in the release folder
tar -xf /tmp/mylawyer-backend.tar -C "$RELEASE_DIR"
cd "$RELEASE_DIR/backend"
npm ci
npm run build

for item in dist migrations public package.json package-lock.json; do
  rm -rf "${APP_DIR:?}/$item"
  cp -a "$RELEASE_DIR/backend/$item" "$APP_DIR/$item"
done

cd "$APP_DIR"
npm ci --omit=dev
chown -R www-data:www-data "$APP_DIR"

# Migrations run when the server starts
systemctl restart "$SERVICE"

sleep 5
PORT="$(grep -E '^PORT=' .env 2>/dev/null | cut -d= -f2 | tr -d ' \r' || true)"
HEALTH="$(curl -s "http://127.0.0.1:${PORT:-4000}/api/v1/health")"
echo "$HEALTH"
echo "$HEALTH" | grep -q '003_service_lifecycle.sql' || { echo "Migration 003 is not applied. Check the server logs."; exit 1; }
curl -s -o /dev/null -w 'Control page: %{http_code}\n' "http://127.0.0.1:${PORT:-4000}/api/v1/admin-panel"

rm -rf "$RELEASE_DIR" /tmp/mylawyer-backend.tar
echo "Deployment finished. Backup: $BACKUP_FILE"
