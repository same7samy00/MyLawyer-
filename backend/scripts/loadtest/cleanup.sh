#!/usr/bin/env bash
# Removes the load-test copy completely. Production is not touched.
set -u
systemctl stop mylawyer-loadtest 2>/dev/null
systemctl reset-failed mylawyer-loadtest 2>/dev/null
sudo -u postgres dropdb --if-exists mylawyer_loadtest
rm -rf /opt/mylawyer-loadtest /tmp/lt
echo "loadtest copy removed"
systemctl is-active mylawyer-backend
curl -s http://127.0.0.1:4000/api/v1/health; echo
