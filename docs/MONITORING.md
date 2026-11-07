# المراقبة

**آخر تحقق:** 2026-11-07. **الوضع:** نقطة صحة، وسجلات، و**مراقب بينبّه بالإيميل** على السيرفرين من 2026-11-07.

## 0. المراقب والتنبيه
`backend/ops/mylawyer-watch.sh` (على السيرفر `/usr/local/bin/mylawyer-watch`) كل 5 دقايق من `/etc/cron.d/mylawyer-watch`، وحالته في `/var/lib/mylawyer-watch` وسجله `/var/log/mylawyer-watch.log`.
- **الجديد (`api`):** الخادم والقاعدة، والموقع من بره، وصور الخريطة، والطرق، وشهادتين (أكتر من 14 يوم)، والنسخة اليومية (أحدث من 26 ساعة)، والمساحة (أقل من 80%)، والذاكرة (أقل من 90%).
- **القديم (`maps`):** سيرفر الباك إند من بره، والخرايط عنده، والمساحة، والذاكرة. يعني كل سيرفر بيراقب التاني.
- **الإيميل:** لـ `same7redaa@gmail.com` (`MYLAWYER_ALERT_TO`) بعد فشلين ورا بعض، وإيميل تاني لما يرجع. من الجديد `noreply@my-lawyer.online` (اتجرّب ووصل)، ومن القديم `alerts@maps.my-lawyer.online` (**جوجل بيرفضه لحد ما سجل SPF لـ `maps` يتضاف في Hostinger**).

## 1. الصحة
| الفحص | العنوان | السليم |
|---|---|---|
| الخادم والقاعدة | `https://my-lawyer.online/api/v1/health` | `{"status":"UP","database":"CONNECTED","release":"<commit>"}` |
| اللوحة | `https://my-lawyer.online/api/v1/admin-panel` | 200 |
| الخرايط | `https://maps.my-lawyer.online/map/v2/12/2449/1701.webp` | 200، و`X-Cache-Status: HIT` |
| الطرق | `https://maps.my-lawyer.online/osrm/route/v1/driving/31.23,30.04;31.25,30.0?overview=false` | `"code":"Ok"` |

## 2. السجلات
| السجل | فين | الأمر |
|---|---|---|
| أخطاء الخادم | journald (JSON من Fastify) | `journalctl -u mylawyer-backend --since "-1h" -p err --no-pager` |
| طلبات الويب | `/var/log/nginx/mylawyer_access.log` و`error.log` | `tail -f` |
| الإيميل | `/var/log/mail.log` | `grep status= /var/log/mail.log \| tail` |
| استعلامات القاعدة الأبطأ من نص ثانية | سجل PostgreSQL | `journalctl -u postgresql@16-main --since "-1d" \| grep duration` |
| الرفع | GitHub Actions | صفحة Actions في الريبو |
| رسم الخريطة | `/var/log/mylawyer-map-seed.log` على القديم | `tail -1` |

## 3. الموارد
`sar -u 1 5` (المعالج)، و`sar -r` (الذاكرة)، و`df -h /`، و`free -m`. sysstat بيحفظ تاريخ كل 10 دقايق.

## 4. اللي لازم يتراقب (لما التنبيه يتعمل)
| المؤشر | الحد اللي ينبّه |
|---|---|
| `/health` | مش UP دقيقتين |
| الخرايط والطرق | مش 200 دقيقتين |
| انتهاء الشهادات | أقل من 14 يوم |
| المساحة | أكتر من 80% |
| الذاكرة | أكتر من 85% لمدة 10 دقايق |
| آخر نسخة يومية | أقدم من 26 ساعة |
| أخطاء 500 | أكتر من 10 في 5 دقايق |

## 5. ناقص
- سجل SPF لـ `maps` عشان تنبيهات القديم توصل.
- أخطاء التطبيق على الموبايلات (Sentry أو بديل، محتاج قرار).
- لوحة أرقام (مش محتاجينها قبل الإطلاق).
