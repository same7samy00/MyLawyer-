#!/usr/bin/env bash
# Copies the daily backups to the maps server (one folder only, enforced on that side by rrsync).
# The two servers keep each other's copies, so losing one server does not lose the data.
set -euo pipefail
rsync -a --delete -e "ssh -i /root/.ssh/mylawyer_backup -o BatchMode=yes" --include="daily-*.sql.gz" --include="storage-*.tar.gz" --include="old-server-final-*.sql.gz" --exclude="*" /root/mylawyer-backups/ root@13.140.141.32:/
echo "offsite copy done $(date -Is)"
