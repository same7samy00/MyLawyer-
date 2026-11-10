#!/usr/bin/env bash
# The second server takes over when the main server is down. Run on the second server as root:
#   bash /root/take-over.sh --check   only says whether everything is ready, changes nothing
#   bash /root/take-over.sh           takes over (refuses while the main server still answers)
# After it: point my-lawyer.online and www to this server's address in the DNS (docs/BACKUP_AND_RECOVERY.md).
# There is no way back by itself: the old main server must not run the app again (main-guard.sh stops it).
set -euo pipefail

APP_DIR=/var/www/mylawyer/backend
ENV="$APP_DIR/.env"
MAIN=10.77.0.1
MARK=/etc/mylawyer/promoted
problems=0

say() { echo "- $*"; }
bad() { echo "! $*"; problems=$((problems + 1)); }

echo "Checking the second server"
[ "$(sudo -u postgres psql -qtAc 'SELECT pg_is_in_recovery()')" = "t" ] && say "database copy: ready" \
  || { [ -e "$MARK" ] && say "database: already the main one" || bad "database copy is not a copy"; }
lag="$(sudo -u postgres psql -qtAc "SELECT COALESCE(EXTRACT(EPOCH FROM now() - pg_last_xact_replay_timestamp())::int, 0)")"
say "last change copied ${lag}s ago (it grows when nothing changes on the main server, that is normal)"
redis-cli -a "$(grep -oP 'requirepass \K\S+' /etc/redis/mylawyer.conf)" --no-auth-warning ping | grep -q PONG \
  && say "local fast memory: ready" || bad "local fast memory doesn't answer"
nginx -t -q 2>/dev/null && grep -q my-lawyer.online /etc/nginx/sites-enabled/* && say "Nginx: ready for the domain" || bad "Nginx is not ready for the domain"
[ -s /etc/letsencrypt/live/my-lawyer.online/fullchain.pem ] && say "certificate: present" || bad "certificate missing"
[ -d /var/www/mylawyer/site ] && [ -n "$(ls -A /var/www/mylawyer/site)" ] && say "website files: present" || bad "website files missing"
say "uploaded files: $(find /var/www/mylawyer/storage -type f | wc -l)"
curl -s --max-time 3 http://127.0.0.1:4000/api/v1/health | grep -q '"status":"UP"' && say "backend here: UP" || bad "backend here doesn't answer"

main_up=no
curl -s --max-time 3 "http://$MAIN:4000/api/v1/health" | grep -q '"status":"UP"' && main_up=yes
say "main server answering: $main_up"

if [ "${1:-}" = "--check" ]; then
  [ "$problems" -eq 0 ] && echo "Ready to take over." || echo "Not ready: $problems problem(s)."
  exit "$problems"
fi

[ -e "$MARK" ] && { echo "Already took over."; exit 0; }
[ "$main_up" = no ] || { echo "The main server still answers. Taking over now would leave two main databases. Stopping."; exit 1; }
[ "$problems" -eq 0 ] || { echo "Not ready, stopping."; exit 1; }

echo "Taking over"
mkdir -p /etc/mylawyer
date -Is > "$MARK"
sudo -u postgres psql -qtAc 'SELECT pg_promote(true, 60)' | grep -q t
say "database: now the main one"

cp "$ENV" "$ENV.before-take-over"
PASS="$(grep -oP 'requirepass \K\S+' /etc/redis/mylawyer.conf)"
sed -i -E \
  -e "s#^(DATABASE_URL=postgres(ql)?://[^@]+@)$MAIN#\\1127.0.0.1#" \
  -e "s#^REDIS_URL=.*#REDIS_URL=redis://:$PASS@127.0.0.1:6379#" \
  -e "/^(DATABASE_READ_URL|JOB_WORKER|TRUST_PROXY)=/d" "$ENV"
echo "TRUST_PROXY=127.0.0.1" >> "$ENV"
systemctl restart mylawyer-backend
systemctl enable --now certbot.timer >/dev/null 2>&1 || true

for _ in $(seq 1 30); do
  curl -s --max-time 3 http://127.0.0.1:4000/api/v1/health | grep -q '"database":"CONNECTED"' && break
  sleep 2
done
say "backend here: $(curl -s --max-time 3 http://127.0.0.1:4000/api/v1/health)"
echo
echo "Done. Now point my-lawyer.online and www to $(ip -4 -o addr show eth0 | awk '{print $4}' | cut -d/ -f1) in the DNS."
