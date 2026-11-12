# الاختبارات

**آخر تشغيل:** 2026-11-11. القاعدة في `WORK_RULES.md` القسم 4: مفيش «خلصت» من غير تشغيل الفحوصات، والنتيجة الحقيقية تتكتب.

## 1. الأوامر
| الجزء | الأمر | النتيجة يوم 2026-11-11 |
|---|---|---|
| التطبيق: تحليل | `flutter analyze` | نضيف |
| التطبيق: اختبارات | `flutter test` | 156 نجحوا و4 متخطين (2026-11-12) (الرابع: اختبار التحويل، بيشتغل بس مع `--dart-define=WALLET_TRANSFERS=true`) |
| الخادم: الأنواع | `cd backend && npx tsc --noEmit` | نضيف |
| الخادم: اختبارات | `cd backend && npm test` | 214 نجحوا (2026-11-12، منهم `field.test.ts`: الخدمات الميدانية) |
| الخادم: كود مش مستخدم | `npx tsc --noEmit --noUnusedLocals --noUnusedParameters` | نضيف |
| الخادم: ثغرات المكتبات | `npm audit --omit=dev` | صفر |

Flutter في `C:\src\flutter\bin\flutter.bat`. الرفع التلقائي بيشغّل `tsc` و`npm test` قبل أي نشر، ولو فشلوا الرفع بيقف.

## 2. اختبارات الخادم (`backend/tests/`)
بتشتغل على قاعدة جوه الذاكرة (PGlite) من `harness.ts`، ومن غير Redis ولا TomTom ولا Firebase. **اختبار جديد لازم يتضاف لسكريبت `test` في `backend/package.json`**، وإلا مش هيشتغل.
| الملف | بيغطي |
|---|---|
| `pricing-money.test.ts` | الأسعار، والعمولة، والضريبة، والرصيد |
| `order-flow.test.ts` و`requests.test.ts` | رحلة «محاميك حالاً» من الطلب للإنهاء |
| `tickets-settlement.test.ts` و`support.test.ts` | التذاكر، والتجميد، والتسوية |
| `reviews.test.ts` و`showcase.test.ts` | التقييمات، والخريطة والقوايم |
| `platform.test.ts` و`hardening.test.ts` | الصلاحيات، والحدود، ومحاولات الدخول، وكود اللوحة |
| `live-tracking.test.ts` | المكان اللحظي والخط المباشر |
| `consultations.test.ts` | الاستشارة السريعة |
| `password-queue.test.ts` و`job-queue.test.ts` | طابور كلمات السر، وطابور الإشعارات |
| `notifications.test.ts` و`app-client.test.ts` | الإشعارات، وأعطال التطبيق والتحديث الإجباري |
| `account-deletion.test.ts` | حذف الحساب: كلمة السر، والأسباب اللي بتمنعه، والخروج من كل مكان، والإلغاء بالدخول، والمسح بعد 30 يوم. وحسابات مراجعة جوجل ما بتتمسحش ولا بتتوقف |
| `storm.test.ts` | «العاصفة»: حوالي 1600 عملية عشوائية مع بعض، وبعدها مفيش خطأ خادم ولا حجز مرتين ولا جنيه ضاع |

## 3. اختبارات التطبيق (`test/`)
بتشتغل على خادم وهمي محلي (`test/helpers/fake_backend.dart`)، وما بتكلمش الإنتاج.
| المكان | بيغطي |
|---|---|
| `test/session/` | فتح التطبيق والجلسة، والدخول والخروج، والتنقل، ورحلة الطلب، والاستشارة، والمدفوعات، والتحويل، ومربعات الخريطة |
| `widget_test.dart` | الشاشات والمكونات المشتركة |
| `press_feedback_test.dart` و`order_status_widgets_test.dart` و`auth_error_banner_test.dart` و`lawyer_profile_summary_test.dart` | مكونات بعينها |
| `app_build_test.dart` | رقم النسخة واحد في `pubspec.yaml` و`AppConfig` |
| `api_integration_test.dart` | 3 فحوص قراية على الخادم الحقيقي. **متخطية دايمًا** (دول الـ 3 المتخطين) إلا لو اتشغلت بـ `--dart-define=RUN_LIVE_API_TESTS=true` |

## 4. فحوص على السيرفر الشغال (قراية بس)
| الفحص | الأمر |
|---|---|
| الصحة | `curl https://my-lawyer.online/api/v1/health` لازم يرجع `UP` و`release` برقم آخر commit غيّر `backend/` |
| السيرفر التاني | من الأساسي: `curl http://10.77.0.2:4000/api/v1/health` |
| النسخة الحية | `SERVER_ARCHITECTURE.md` القسم 5 |
| تجديد الشهادة | `certbot renew --dry-run` على الأساسي (بياخد حوالي 6 دقايق) |
| تاريخ القاعدة | `sudo -u postgres pgbackrest --stanza=mylawyer check` |
| اختبار الضغط | `LOAD_TEST.md` (على قاعدة مؤقتة، مش على بيانات الإنتاج) |

## 5. اللي مفيش عليه اختبار
- الآيفون: ما اتبناش ولا اتجرب.
- طلب كامل بين موبايلين حقيقيين بآخر نسخة، والإشعار والتطبيق مقفول.
- لوحة التحكم: مفيش اختبارات واجهة. مساراتها متغطية في اختبارات الخادم، وشكلها بيتراجع بـ `npm run preview:panel`.
- تحويل حقيقي للسيرفر التاني (`take-over.sh`): `--check` بس هو اللي اتجرب.
