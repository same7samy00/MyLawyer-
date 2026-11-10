# المراقبة

**آخر تحقق:** 2026-11-07. **الوضع:** نقطة صحة، وسجلات، و**مراقب بينبّه بالإيميل** على السيرفرين من 2026-11-07.

## 0. المراقب والتنبيه
`backend/ops/mylawyer-watch.sh` (على السيرفر `/usr/local/bin/mylawyer-watch`) كل 5 دقايق من `/etc/cron.d/mylawyer-watch`، وحالته في `/var/lib/mylawyer-watch` وسجله `/var/log/mylawyer-watch.log`.
- **الجديد (`api`):** الخادم والقاعدة، والموقع من بره، وصور الخريطة، والطرق، وشهادتين (أكتر من 14 يوم)، والنسخة اليومية (أحدث من 26 ساعة)، والمساحة (أقل من 80%)، والذاكرة (أقل من 90%).
- **التاني (`maps`):** السيرفر الأساسي من بره، والمساحة، والذاكرة.
- **علامات «السيرفر بدأ يتقل» (في الكود من 2026-11-11، ولسه ما اتنسختش على السيرفرين):** المعالج فوق 60% من ربع ساعة، والخادم بيرد على فحص الصحة في أكتر من نص ثانية، واتصالات القاعدة فوق 70%. إيميلها مختلف: «السيرفر بدأ يتقل» مش «مشكلة»، وبيقول إن ده وقت التكبير (`LOAD_TEST.md` القسم 4). التفعيل: نسخ `backend/ops/mylawyer-watch.sh` لـ `/usr/local/bin/mylawyer-watch` على السيرفرين (بموافقة صاحب المشروع).
- **أعطال التطبيق على موبايلات الناس:** بتتسجل في جدول `app_errors` (`POST /app/errors`، آخر 30 يوم). القراية: `sudo -u postgres psql mylawyer_prod -c "SELECT created_at, app_build, platform, left(message, 120) FROM app_errors ORDER BY id DESC LIMIT 30"`. وفي اللوحة: صفحة «نسخة التطبيق وأعطاله» (نفس العطل مرة واحدة بعدد مراته والمستخدمين، والضغط عليه بينسخ تفاصيله).
- **الإيميل:** لـ `same7redaa@gmail.com` (`MYLAWYER_ALERT_TO`) بعد فشلين ورا بعض، وإيميل تاني لما يرجع. من الجديد `noreply@my-lawyer.online` (اتجرّب ووصل)، ومن القديم `alerts@maps.my-lawyer.online` (**جوجل بيرفضه لحد ما سجل SPF لـ `maps` يتضاف في Hostinger**).

## 1. الصحة
| الفحص | العنوان | السليم |
|---|---|---|
| الخادم والقاعدة | `https://my-lawyer.online/api/v1/health` | `{"status":"UP","database":"CONNECTED","release":"<commit>"}` |
| اللوحة | `https://my-lawyer.online/api/v1/admin-panel` | 200 |
| خزنة الخريطة | `https://my-lawyer.online/map/t/12/2405/1712.png` | 200 |

## 2. السجلات
| السجل | فين | الأمر |
|---|---|---|
| أخطاء الخادم | journald (JSON من Fastify) | `journalctl -u mylawyer-backend --since "-1h" -p err --no-pager` |
| طلبات الويب | `/var/log/nginx/mylawyer_access.log` و`error.log` | `tail -f` |
| الإيميل | `/var/log/mail.log` | `grep status= /var/log/mail.log \| tail` |
| استعلامات القاعدة الأبطأ من نص ثانية | سجل PostgreSQL | `journalctl -u postgresql@16-main --since "-1d" \| grep duration` |
| الرفع | GitHub Actions | صفحة Actions في الريبو |

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
