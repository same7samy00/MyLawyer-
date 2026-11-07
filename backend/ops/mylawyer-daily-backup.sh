#!/usr/bin/env bash
# Daily backup on the backend server (cron at 03:30, /etc/cron.d/mylawyer-backup).
# The database as a compressed SQL dump and the uploaded files (storage), each kept 14 days.
# docs/BACKUP_AND_RECOVERY.md explains how to restore.
set -euo pipefail

DIR=/root/mylawyer-backups
APP=/var/www/mylawyer/backend
STAMP=$(date +%Y%m%d)
KEEP_DAYS=14

mkdir -p "$DIR"
chmod 700 "$DIR"
DB=$(grep -E '^DATABASE_URL=' "$APP/.env" | head -1 | cut -d= -f2- | tr -d '"'"'"' \r')

pg_dump "$DB" | gzip > "$DIR/daily-$STAMP.sql.gz.tmp"
# An empty dump means something went wrong: keep the last good one and fail loudly
if [ "$(gzip -dc "$DIR/daily-$STAMP.sql.gz.tmp" | wc -c)" -lt 1000 ]; then
  rm -f "$DIR/daily-$STAMP.sql.gz.tmp"
  echo "mylawyer backup: database dump looks empty" >&2
  exit 1
fi
mv "$DIR/daily-$STAMP.sql.gz.tmp" "$DIR/daily-$STAMP.sql.gz"

tar -C /var/www/mylawyer -czf "$DIR/storage-$STAMP.tar.gz.tmp" storage
mv "$DIR/storage-$STAMP.tar.gz.tmp" "$DIR/storage-$STAMP.tar.gz"

chmod 600 "$DIR"/daily-*.sql.gz "$DIR"/storage-*.tar.gz
find "$DIR" -maxdepth 1 \( -name 'daily-*.sql.gz' -o -name 'storage-*.tar.gz' \) -mtime +"$KEEP_DAYS" -delete
echo "mylawyer backup: done $(du -sh "$DIR/daily-$STAMP.sql.gz" | cut -f1) database, $(du -sh "$DIR/storage-$STAMP.tar.gz" | cut -f1) files"
