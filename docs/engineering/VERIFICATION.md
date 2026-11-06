# تقرير الفحوصات

**التاريخ:** 2026-11-06. الجهاز: Windows 11 عند صاحب المشروع. الفرع `claude/engineering-review`، وقبل أي تعديل في الكود (المراجعة دي توثيق بس).

| الأمر | المكان | النتيجة | الحالة |
|---|---|---|---|
| `npx tsc --noEmit` | `backend` | من غير أخطاء | RUNTIME VERIFIED |
| `npm test` | `backend` | 141 نجحوا، 0 فشلوا، 30 مجموعة، في 41.5 ثانية | RUNTIME VERIFIED |
| `npm audit --omit=dev` | `backend` | `found 0 vulnerabilities` | RUNTIME VERIFIED |
| `flutter analyze` | الجذر | `No issues found!` (89.6 ثانية) | RUNTIME VERIFIED |
| `flutter test` | الجذر | 128 نجحوا و3 متخطين (`All tests passed!`) | RUNTIME VERIFIED |
| `flutter run --profile` | - | ما اتشغلش | UNVERIFIED |

**حدود:** اختبارات الخادم بتشتغل على PGlite باتصال واحد، فالأقفال مع اتصالات متزامنة على PostgreSQL حقيقي ما اتجربتش (ده مكتوب كمان في `HANDOFF.md`). والاختبارات المتخطية التلاتة في `test/api_integration_test.dart` محتاجة خادم شغال.

## قراءات من السيرفر (من غير أي تعديل)
| اللي اتقرا | النتيجة |
|---|---|
| `ss -tlnp` | المفتوح للخارج 22 و25 و80 و443. و25 مقفول من UFW |
| `ufw status` | مسموح 22 و80 و443 بس |
| `systemctl is-active` | `mylawyer-backend` و`nginx` و`postgresql` شغالين |
| `docker ps` | `mylawyer-osrm` و`mylawyer-tileserver` على `127.0.0.1` |
| `journalctl -u mylawyer-backend -p err` آخر ساعة | مفيش أخطاء |
| الذاكرة والقرص | 3.3 من 7.8 جيجا، وSwap 4 جيجا مش مستخدم، والقرص 25% |
| إعدادات PostgreSQL | `shared_buffers=1GB` و`max_connections=120` و`work_mem=8MB` |
| استعلامات على `mylawyer_prod` | **BLOCKED**: أداة الحماية رفضت الاستعلام على قاعدة الإنتاج، فما اتقرتش إحصائيات الجداول ولا مستوى الـ migrations |

## قياس من بره (طلبات قليلة، مش اختبار حمل)
| المسار | متوسط الرد | الحجم |
|---|---|---|
| `GET /api/v1/health` (5 مرات) | اتصال 0.107 ث، TLS 0.199 ث، أول بايت 0.269 ث، يعني الخادم حوالي 70 ملي ثانية | صغير |
| `GET /api/v1/lawyers/nearby` (3 مرات) | 0.24 ث | 46 بايت (مفيش محامين متاحين ساعتها، فالرقم ده مش بيقيس الحمل) |
| `GET /api/v1/admin-panel/script` (3 مرات) | 0.34 ث | 36 كيلوبايت مضغوطة gzip، ومتخزنة سنة |
