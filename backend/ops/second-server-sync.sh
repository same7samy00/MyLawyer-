#!/usr/bin/env bash
# Runs on the main server every minute (mylawyer-second-sync.timer), as root, over the private link.
# Keeps on the second server what it needs to take over alone: the uploaded files, the website, the certificate
# and the Nginx setup. The database copy keeps itself up to date, this is everything else.
set -uo pipefail

SECOND="$(cat /etc/mylawyer/second-server 2>/dev/null || true)"
[ -n "$SECOND" ] || exit 0
SSH="ssh -o BatchMode=yes -o ConnectTimeout=10"

rsync -a --delete -e "$SSH" /var/www/mylawyer/storage/ "root@$SECOND:/var/www/mylawyer/storage/"
rsync -a --delete -e "$SSH" /var/www/mylawyer/site/ "root@$SECOND:/var/www/mylawyer/site/"
rsync -a -e "$SSH" /etc/letsencrypt/ "root@$SECOND:/etc/letsencrypt/"

# Nginx is the same on both, so the second server can answer the domain the moment it points there.
# It reloads only when something changed, and only if the setup passes its test
changed="$(rsync -a --delete --itemize-changes -e "$SSH" /etc/nginx/ "root@$SECOND:/etc/nginx/")"
if [ -n "$changed" ]; then
  $SSH "root@$SECOND" 'mkdir -p /var/cache/nginx/tomtom /var/cache/nginx/lawyers /var/cache/nginx/signed_in /var/www/letsencrypt && chown -R www-data:www-data /var/cache/nginx && nginx -t -q && systemctl reload nginx' \
    || echo "Second server: the Nginx setup did not pass its test there"
fi
