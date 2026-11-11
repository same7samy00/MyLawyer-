#!/usr/bin/env bash
# Health watch (cron every 5 minutes, /etc/cron.d/mylawyer-watch). docs/MONITORING.md.
# The backend server runs it as "api", the maps server as "maps", so each one also watches the other.
# A check has to fail twice in a row before an email goes out, and one more email says when it is back.
set -uo pipefail

ROLE="${1:-api}"
TO="${MYLAWYER_ALERT_TO:-same7redaa@gmail.com}"
# Each server sends as its own name, so the mail passes the domain's SPF check
if [ "$ROLE" = "api" ]; then FROM="noreply@my-lawyer.online"; else FROM="alerts@maps.my-lawyer.online"; fi
STATE_DIR=/var/lib/mylawyer-watch
mkdir -p "$STATE_DIR"

declare -A RESULT

http_ok() { # url, expected text (optional)
  local body
  body=$(curl -s --max-time 15 -w '\n%{http_code}' "$1") || return 1
  [ "$(tail -n1 <<<"$body")" = "200" ] || return 1
  [ -z "${2:-}" ] || grep -q "$2" <<<"$body"
}

cert_days() { # host. Asks this server's own Nginx: from outside Cloudflare answers with its own certificate
  local end
  end=$(echo | openssl s_client -servername "$1" -connect "127.0.0.1:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
  [ -n "$end" ] || { echo -1; return; }
  echo $(( ($(date -d "$end" +%s) - $(date +%s)) / 86400 ))
}

check() { # name, command...
  local name=$1; shift
  if "$@" >/dev/null 2>&1; then RESULT[$name]=ok; else RESULT[$name]=fail; fi
}

disk_ok() { [ "$(df --output=pcent / | tail -1 | tr -dc 0-9)" -lt 80 ]; }
ram_ok() { [ "$(free | awk '/Mem:/ {printf "%d", ($3/$2)*100}')" -lt 90 ]; }

# Early signs that the server is filling up, long before anything breaks (docs/LOAD_TEST.md section 4).
# Their names start with HEAVY, so the email says "getting heavy" and not "broken".
HEAVY="ضغط"
# The processors busy over 60% on average for the last 15 minutes
load_ok() { awk -v cores="$(nproc)" '{ exit !($3 / cores < 0.6) }' /proc/loadavg; }
# The backend answering its own health check, which reads the database, in under half a second
speed_ok() {
  local seconds
  seconds=$(curl -s -o /dev/null --max-time 15 -w '%{time_total}' http://127.0.0.1:4000/api/v1/health) || return 1
  awk -v t="$seconds" 'BEGIN { exit !(t < 0.5) }'
}
# Database connections in use under 70% of the limit. If the count can't be read, nothing is claimed
db_room_ok() {
  local used
  used=$(sudo -u postgres psql -qtAc "SELECT count(*) * 100 / current_setting('max_connections')::int FROM pg_stat_activity" 2>/dev/null | tr -dc 0-9)
  [ -z "$used" ] || [ "$used" -lt 70 ]
}

if [ "$ROLE" = "api" ]; then
  check "الخادم وقاعدة البيانات" http_ok http://127.0.0.1:4000/api/v1/health '"database":"CONNECTED"'
  check "الموقع من بره" http_ok https://my-lawyer.online/api/v1/health '"status":"UP"'
  check "خزنة الخريطة" http_ok https://my-lawyer.online/map/t/12/2405/1712.png
  check "شهادة my-lawyer.online" test "$(cert_days my-lawyer.online)" -ge 14
  check "النسخة الاحتياطية اليومية" test -n "$(find /root/mylawyer-backups -name 'daily-*.sql.gz' -mmin -1560 2>/dev/null)"
  check "$HEAVY: الخادم بيرد في أكتر من نص ثانية" speed_ok
  check "$HEAVY: اتصالات قاعدة البيانات فوق 70%" db_room_ok
else
  check "سيرفر الباك إند من بره" http_ok https://my-lawyer.online/api/v1/health '"status":"UP"'
fi
check "$HEAVY: المعالج فوق 60% من ربع ساعة" load_ok
check "المساحة (أقل من 80%)" disk_ok
check "الذاكرة (أقل من 90%)" ram_ok

send() { # subject, body
  printf 'From: My Lawyer <%s>\nTo: %s\nSubject: =?UTF-8?B?%s?=\nMIME-Version: 1.0\nContent-Type: text/plain; charset=UTF-8\n\n%s\n' \
    "$FROM" "$TO" "$(printf '%s' "$1" | base64 -w0)" "$2" | /usr/sbin/sendmail -f "$FROM" "$TO"
}

HOST=$(hostname)
for name in "${!RESULT[@]}"; do
  key=$(printf '%s' "$name" | md5sum | cut -c1-12)
  fails=$(cat "$STATE_DIR/$key.fails" 2>/dev/null || echo 0)
  alerted=$(cat "$STATE_DIR/$key.alerted" 2>/dev/null || echo 0)
  if [ "${RESULT[$name]}" = fail ]; then
    fails=$((fails + 1)); echo "$fails" > "$STATE_DIR/$key.fails"
    if [ "$fails" -ge 2 ] && [ "$alerted" = 0 ] && [[ "$name" == "$HEAVY"* ]]; then
      send "My Lawyer: السيرفر بدأ يتقل" "السيرفر: $HOST
العلامة: ${name#"$HEAVY: "}
من حوالي $((fails * 5)) دقيقة
الوقت: $(date '+%Y-%m-%d %H:%M')

ده مش عطل، التطبيق شغال. لو الإيميل ده بيتكرر في وقت الزحمة، ده وقت تكبير السيرفر:
أول خطوة سيرفر لقاعدة البيانات لوحدها (docs/LOAD_TEST.md القسم 4).
هيوصلك إيميل تاني لما الحمل يهدى."
      echo 1 > "$STATE_DIR/$key.alerted"
      logger -t mylawyer-watch "HEAVY $name"
    elif [ "$fails" -ge 2 ] && [ "$alerted" = 0 ]; then
      send "My Lawyer: مشكلة في $name" "السيرفر: $HOST
الفحص: $name
الحالة: فشل $fails مرات ورا بعض، من حوالي $((fails * 5)) دقيقة
الوقت: $(date '+%Y-%m-%d %H:%M')

هيوصلك إيميل تاني لما يرجع."
      echo 1 > "$STATE_DIR/$key.alerted"
      logger -t mylawyer-watch "ALERT $name"
    fi
  else
    if [ "$alerted" = 1 ] && [[ "$name" == "$HEAVY"* ]]; then
      send "My Lawyer: الحمل على السيرفر هدي" "السيرفر: $HOST
العلامة اللي كانت ظاهرة: ${name#"$HEAVY: "}
الوقت: $(date '+%Y-%m-%d %H:%M')"
      logger -t mylawyer-watch "CALM $name"
    elif [ "$alerted" = 1 ]; then
      send "My Lawyer: رجع يشتغل: $name" "السيرفر: $HOST
الفحص: $name رجع سليم
الوقت: $(date '+%Y-%m-%d %H:%M')"
      logger -t mylawyer-watch "RECOVERED $name"
    fi
    echo 0 > "$STATE_DIR/$key.fails"; echo 0 > "$STATE_DIR/$key.alerted"
  fi
done
