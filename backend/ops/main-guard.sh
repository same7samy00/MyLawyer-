#!/usr/bin/env bash
# Runs on the main server before its backend starts (ExecStartPre in mylawyer-backend.service).
# If the second server took over while this one was down, this server's database is old: its backend must not
# start, or two servers would act on different data (send the same notifications, take payments twice).
# If the second server can't be reached, the backend starts as usual: that is the normal case of a second server down.
set -uo pipefail

SECOND="$(cat /etc/mylawyer/second-server 2>/dev/null || true)"
[ -n "$SECOND" ] || exit 0
if ssh -o BatchMode=yes -o ConnectTimeout=5 "root@$SECOND" 'test -e /etc/mylawyer/promoted' 2>/dev/null; then
  echo "The second server took over (/etc/mylawyer/promoted there). This server's backend stays off. docs/BACKUP_AND_RECOVERY.md"
  exit 1
fi
exit 0
