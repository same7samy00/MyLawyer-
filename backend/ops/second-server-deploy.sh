#!/usr/bin/env bash
# Runs on the second server, called by deploy.sh on the main server after the main server took the release:
#   tar of the release on stdin | bash second-server-deploy.sh <release id>
# The second server runs the same code against the main database. If the new release doesn't answer as healthy,
# the second server's backend stops instead of running old code, and Nginx on the main server sends everything
# to the main server until the next release.
set -euo pipefail

RELEASE="$1"
APP_DIR="${APP_DIR:-/var/www/mylawyer/backend}"
SERVICE="${SERVICE:-mylawyer-backend}"
ITEMS=(dist migrations public package.json package-lock.json node_modules)
NEXT="$APP_DIR/.next"
PREVIOUS="$APP_DIR/.previous"

rm -rf "$NEXT" "$PREVIOUS"
mkdir -p "$NEXT" "$PREVIOUS"
tar -xf - -C "$NEXT"
chown -R www-data:www-data "$NEXT"

for item in "${ITEMS[@]}"; do
  if [ -e "$APP_DIR/$item" ]; then mv "$APP_DIR/$item" "$PREVIOUS/$item"; fi
  mv "$NEXT/$item" "$APP_DIR/$item"
done
systemctl restart "$SERVICE"

PORT="$(grep -E '^PORT=' "$APP_DIR/.env" 2>/dev/null | cut -d= -f2 | tr -d ' \r' || true)"
good=0
for _ in $(seq 1 45); do
  health="$(curl -s --max-time 3 "http://127.0.0.1:${PORT:-4000}/api/v1/health" || true)"
  if echo "$health" | grep -q '"status":"UP"' && echo "$health" | grep -q "\"release\":\"$RELEASE\""; then
    good=$((good + 1))
    if [ "$good" -ge 6 ]; then
      rm -rf "$NEXT"
      echo "Second server: $health"
      exit 0
    fi
  else
    good=0
  fi
  sleep 2
done

systemctl stop "$SERVICE"
echo "Second server: the release $RELEASE did not answer as healthy, its backend is stopped"
exit 1
