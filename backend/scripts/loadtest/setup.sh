#!/usr/bin/env bash
# Builds an isolated load-test copy of the backend on this server: its own empty database,
# its own folder and port 4100, no push, no email, no rate limits. Nothing of production changes.
set -euo pipefail
LT=/opt/mylawyer-loadtest
PROD=/var/www/mylawyer/backend
DB=mylawyer_loadtest

URL="$(grep -E '^DATABASE_URL=' "$PROD/.env" | head -1 | cut -d= -f2- | tr -d '"'"'"' \r')"
DBUSER="$(echo "$URL" | sed -E 's#^postgres(ql)?://([^:@/]+).*#\2#')"
LTURL="$(echo "$URL" | sed -E "s#/[^/?]+(\?.*)?\$#/$DB\1#")"

systemctl stop mylawyer-loadtest 2>/dev/null || true
sudo -u postgres dropdb --if-exists "$DB"
sudo -u postgres createdb -O "$DBUSER" "$DB"

rm -rf "$LT"
mkdir -p "$LT/storage/public" "$LT/storage/private"
cp -a "$PROD/dist" "$PROD/migrations" "$PROD/public" "$PROD/node_modules" "$PROD/package.json" "$LT/"
SECRET="$(openssl rand -hex 32)"
cat > "$LT/.env" <<EOF
PORT=4100
HOST=127.0.0.1
NODE_ENV=test
DATABASE_URL=$LTURL
JWT_SECRET=$SECRET
SMTP_HOST=127.0.0.1
SMTP_PORT=1
FIREBASE_SERVICE_ACCOUNT_PATH=/nonexistent
PUBLIC_STORAGE_PATH=$LT/storage/public
PRIVATE_STORAGE_PATH=$LT/storage/private
EOF
chmod 600 "$LT/.env"
chown -R www-data:www-data "$LT"

# Same shape as production on the backend server: 5 workers, 15 connections each, the same memory ceiling
systemd-run --unit=mylawyer-loadtest --property=WorkingDirectory="$LT" --uid=www-data --gid=www-data \
  -p MemoryMax=8G -p LimitNOFILE=65535 --setenv=WEB_WORKERS=5 --setenv=DB_POOL_MAX=15 /usr/bin/node dist/server.js

for _ in $(seq 1 30); do
  if curl -s http://127.0.0.1:4100/api/v1/health | grep -q '"status":"UP"'; then echo "loadtest copy UP"; break; fi
  sleep 2
done
curl -s http://127.0.0.1:4100/api/v1/health; echo
