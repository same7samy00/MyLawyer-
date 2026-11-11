# لو حاجة وقفت

**آخر تحقق:** 2026-11-11. كل الأوامر هنا **قراية بس**. أي تصليح على السيرفر محتاج موافقة صاحب المشروع (`ACCESS.md`). الدخول: `ssh -F D:/KAREM/.access/ssh_config mylawyer-api` (الأساسي) أو `mylawyer-vps` (التاني).

## 1. الموقع أو التطبيق مش بيفتح
| اللي ظاهر | السبب الغالب | اتأكد بـ |
|---|---|---|
| صفحة خطأ من Cloudflare رقمها 521 أو 522 | السيرفر مش بيرد على Cloudflare: Nginx واقف، أو Cloudflare ضاف عناوين جديدة مش في الجدار الناري | `systemctl is-active nginx`، و`ufw status \| grep -c Cloudflare` (المفروض 22). العناوين الحالية في `cloudflare.com/ips-v4` و`ips-v6` |
| خطأ 525 أو 526 من Cloudflare | شهادة السيرفر انتهت أو مش سليمة (الوضع Full strict) | `certbot certificates` |
| 502 أو 504 | الخادم نفسه واقف | `systemctl is-active mylawyer-backend`، و`journalctl -u mylawyer-backend --since "-15min" --no-pager \| tail -30` |
| `/health` بيرجع `DEGRADED` | القاعدة مش بترد | `systemctl is-active postgresql@16-main` |
| التطبيق بيقول «حدّث التطبيق» | أقل نسخة مسموحة أعلى من نسخة الموبايل | صفحة «نسخة التطبيق وأعطاله» في اللوحة |
| كل حاجة بترجع 429 | حد الطلبات | `API_DOCUMENTATION.md` القسم 1 |

## 2. الرفع التلقائي فشل
1. صفحة Actions في الريبو: أنهي خطوة فشلت؟ `tsc` أو `npm test` معناها الكود، و`Deploy` معناها السيرفر.
2. لو النسخة الجديدة ما ردّتش، `deploy.sh` بيرجّع القديمة لوحده. اتأكد: `curl https://my-lawyer.online/api/v1/health` و`release` فيه.
3. الـ runner واقف: `systemctl is-active actions.runner.same7samy00-MyLawyer-.vps-mylawyer-api` على الأساسي.

## 3. سكريبت على السيرفر بيقول `bash\r: No such file or directory`
الملف اتنسخ من ويندوز بنهايات سطور ويندوز. ده حصل يوم 2026-11-11 مع `mylawyer-watch` والمراقب وقف 20 دقيقة. الحل: `sed -i 's/\r$//' <الملف>`. المنع: `.gitattributes` بيخلّي كل `.sh` بنهايات لينكس، **وما تنسخش سكريبت بـ `scp` من غير ما تتأكد** (`file <الملف>` لازم ما يقولش CRLF).

## 4. الإيميل مش بيوصل (كود التسجيل أو كود اللوحة)
- `grep status= /var/log/mail.log | tail` على الأساسي: `status=sent` معناه خرج من عندنا.
- لو كود اللوحة هو اللي واقف والدخول ضروري: `ADMIN_LOGIN_CODE=off` في `.env` وإعادة تشغيل الخادم (بموافقة)، وبعد التصليح يتشال.
- الطابور: الإيميلات والإشعارات بتتعاد 5 مرات لوحدها. من غير Redis بتتبعت على طول.

## 5. الإشعارات مش بتوصل للموبايل
- الإشعار موجود جوه التطبيق؟ يبقى المشكلة في Firebase أو في تسجيل الموبايل، مش في الخادم.
- `journalctl -u mylawyer-backend --since "-1h" | grep -i push` على الأساسي.
- التطبيق مقفول خالص: ما اتجربش على موبايل حقيقي (`KNOWN_ISSUES.md`).

## 6. الخريطة فاضية أو وقت الطريق مش بيظهر
- `curl -I https://my-lawyer.online/map/t/12/2405/1712.png` لازم 200.
- 503 من `/routes`: TomTom مش بيرد، أو المفتاح خلص حصته. المحفوظ على الموبايل وعلى السيرفر بيفضل شغال.
- المحاكي: الخادم بيرفض المكان الوهمي (`CURRENT_STATE.md`).

## 7. المراقب بعت «مشكلة» أو «السيرفر بدأ يتقل»
- السجل: `/var/log/mylawyer-watch.log`، والحالة في `/var/lib/mylawyer-watch`.
- «بدأ يتقل» مش عطل: ده وقت التكبير (`LOAD_TEST.md` القسم 4).
- المراقب نفسه ساكت؟ `tail /var/log/mylawyer-watch.log`، وشغّله بإيدك: `/usr/local/bin/mylawyer-watch api`.

## 8. السيرفر التاني
- واقف أو متأخر: الأساسي بيكمل لوحده، وطلبات القراية بترجعله. `SERVER_ARCHITECTURE.md` القسم 5 فيه فحص النسخة الحية.
- الأساسي وقع خالص: `BACKUP_AND_RECOVERY.md` القسم 4.

## 9. بيانات اتمسحت بالغلط
`BACKUP_AND_RECOVERY.md` القسم 3: النسخة اليومية، أو الرجوع لدقيقة معينة. الاتنين بيمسحوا الحالي، فمحتاجين موافقة صريحة ونسخة جديدة قبلهم.

## 10. البناء
| المشكلة | الحل |
|---|---|
| `flutter` مش معروف | المسار الكامل `C:\src\flutter\bin\flutter.bat` |
| نسخة Release موقّعة بمفتاح التجربة | `android/key.properties` أو `android/mylawyer-release.jks` مش في مكانهم |
| `npm test` ما شغّلش اختبار جديد | ضيفه لسكريبت `test` في `backend/package.json` |
| اختبار رقم النسخة فشل | `version` في `pubspec.yaml` و`AppConfig.build` لازم يبقوا واحد |
