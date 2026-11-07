#!/usr/bin/env bash
# The full load test in one go, on the backend server (docs/LOAD_TESTING.md):
# isolated copy, test data, every scenario, server samples, then the copy is removed.
# Results stay in /root/lt-results (results.json, run.log, sar.txt).
set -u
cd /tmp/lt
OUT=/root/lt-results
mkdir -p "$OUT"
exec > >(tee -a "$OUT/run.log") 2>&1
echo "start $(date -Is)"
sed -i "s/\r$//" *.sh
bash setup.sh | tail -2
sudo -u postgres psql -q -d mylawyer_loadtest -f seed.sql | tail -1
sudo -u postgres psql -q -d mylawyer_loadtest -f seed-more.sql | tail -1
[ -d node_modules/autocannon ] || { npm init -y >/dev/null; npm i autocannon@7.15.0 --silent; }
ulimit -n 65535
sar -u -r 5 >"$OUT/sar.txt" 2>&1 &
SAR=$!
for s in ${SCENARIOS:-reads login requests live mix maps routes}; do
  echo "== scenario $s $(date -Is)"
  DUR=${DUR:-20} timeout 2400 node bench.mjs "$s"
  cp -f /tmp/lt/results.json "$OUT/results-$s.json" 2>/dev/null
  curl -s http://127.0.0.1:4000/api/v1/health | grep -q '"status":"UP"' || { echo "production not UP, stopping"; break; }
done
kill $SAR 2>/dev/null
psql "$(grep ^DATABASE_URL= /opt/mylawyer-loadtest/.env | cut -d= -f2-)" -Atc "select pg_size_pretty(pg_database_size('mylawyer_loadtest')), (select count(*) from users), (select count(*) from notifications), (select count(*) from service_requests)" > "$OUT/db-size.txt" 2>&1
bash cleanup.sh
echo "end $(date -Is)"
