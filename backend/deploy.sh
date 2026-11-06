#!/usr/bin/env bash
# Runs on the server from /tmp/mylawyer-backend.tar: sudo bash backend/deploy.sh <release id>
# The database backup always comes first. The new code is built aside, swapped in quickly,
# and the workers are replaced one by one, so the address keeps answering.
# If the new release does not answer as healthy, the previous code comes back by itself.
set -euo pipefail

APP_DIR="${APP_DIR:-/var/www/mylawyer/backend}"
SERVICE="${SERVICE:-mylawyer-backend}"
RELEASE_DIR="$(mktemp -d)"
STAMP="$(date +%Y%m%d-%H%M%S)"
RELEASE="${1:-$STAMP}"
BACKUP_DIR="/root/mylawyer-backups"
NEXT="$APP_DIR/.next"
PREVIOUS="$APP_DIR/.previous"
# What a release replaces. .env and storage stay where they are
ITEMS=(dist migrations public package.json package-lock.json node_modules)

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
tar -C "$APP_DIR" --exclude=node_modules --exclude=storage --exclude=.next --exclude=.previous -czf "$BACKUP_DIR/code-$STAMP.tar.gz" .

# Built aside with the build tools, then reinstalled with the running packages only
tar -xf /tmp/mylawyer-backend.tar -C "$RELEASE_DIR"
cd "$RELEASE_DIR/backend"
npm ci
npm run build
npm ci --omit=dev
echo "$RELEASE" > dist/RELEASE

rm -rf "$NEXT" "$PREVIOUS"
mkdir -p "$NEXT" "$PREVIOUS"
for item in "${ITEMS[@]}"; do mv "$RELEASE_DIR/backend/$item" "$NEXT/$item"; done
chown -R www-data:www-data "$NEXT"

# A change in the main process code needs a full restart, everything else only new workers
MODE=reload
if ! cmp -s "$NEXT/dist/server.js" "$APP_DIR/dist/server.js" || ! systemctl is-active --quiet "$SERVICE"; then
  MODE=restart
fi

swap_in() {
  for item in "${ITEMS[@]}"; do
    if [ -e "$APP_DIR/$item" ]; then mv "$APP_DIR/$item" "$PREVIOUS/$item"; fi
    mv "$NEXT/$item" "$APP_DIR/$item"
  done
}

roll_back() {
  echo "Rolling back to the previous code"
  for item in "${ITEMS[@]}"; do
    if [ -e "$PREVIOUS/$item" ]; then
      rm -rf "${APP_DIR:?}/$item"
      mv "$PREVIOUS/$item" "$APP_DIR/$item"
    fi
  done
  systemctl restart "$SERVICE"
  sleep 5
  echo "After rollback: $(curl -s "http://127.0.0.1:${PORT:-4000}/api/v1/health")"
  echo "The release $RELEASE was not deployed. Database migrations, if any, stay; the backup is $BACKUP_FILE"
  exit 1
}

PORT="$(grep -E '^PORT=' "$APP_DIR/.env" 2>/dev/null | cut -d= -f2 | tr -d ' \r' || true)"

# The new release must answer as healthy several times in a row, every worker included
wait_for_release() {
  local good=0
  for _ in $(seq 1 45); do
    local health
    health="$(curl -s --max-time 3 "http://127.0.0.1:${PORT:-4000}/api/v1/health" || true)"
    if echo "$health" | grep -q '"status":"UP"' && echo "$health" | grep -q "\"release\":\"$RELEASE\""; then
      good=$((good + 1))
      [ "$good" -ge 6 ] && { echo "$health"; return 0; }
    else
      good=0
    fi
    sleep 2
  done
  return 1
}

swap_in
echo "Activating the release $RELEASE ($MODE)"
if [ "$MODE" = reload ]; then
  kill -HUP "$(systemctl show -p MainPID --value "$SERVICE")"
else
  systemctl restart "$SERVICE"
fi

wait_for_release || { echo "The new release did not answer as healthy."; roll_back; }

# The public website (landing page and policies) is served by Nginx from the site folder
SITE_DIR="${SITE_DIR:-/var/www/mylawyer/site}"
mkdir -p "$SITE_DIR"
rm -rf "${SITE_DIR:?}"/*
cp -a "$APP_DIR/public/site/." "$SITE_DIR/"
chown -R www-data:www-data "$SITE_DIR"

curl -s -o /dev/null -w 'Control page: %{http_code}\n' "http://127.0.0.1:${PORT:-4000}/api/v1/admin-panel"
curl -sk -o /dev/null -w 'Website: %{http_code}\n' --resolve my-lawyer.online:443:127.0.0.1 https://my-lawyer.online/

rm -rf "$RELEASE_DIR" "$NEXT" /tmp/mylawyer-backend.tar
echo "Deployment finished ($MODE). Release: $RELEASE. Backup: $BACKUP_FILE. The previous code stays in $PREVIOUS until the next release."
