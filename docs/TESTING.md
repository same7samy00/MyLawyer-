# الاختبارات

**آخر تحقق:** 2026-11-07: الخادم **163 نجحوا**، والتطبيق **129 نجحوا و3 متخطين**.

## 1. التشغيل
| الجزء | الأمر | بيستخدم |
|---|---|---|
| التطبيق: الفحص | `flutter analyze` | لازم «No issues found!» |
| التطبيق: الاختبارات | `flutter test` | خادم وهمي محلي `test/helpers/fake_backend.dart`، ومش بيكلم الإنتاج |
| الخادم: الأنواع | `npx tsc --noEmit` من `backend` | |
| الخادم: الاختبارات | `npm test` من `backend` | PGlite (PostgreSQL جوه الذاكرة) بكل الـ migrations، ومش محتاج قاعدة حقيقية |
| اللوحة | `npm run preview:panel` من `backend` | تجربة يدوية في المتصفح |

على ويندوز Flutter في `C:\src\flutter\bin\flutter.bat`.

## 2. ملفات الخادم (`backend/tests`)
`pricing-money` (الأسعار والعمولة)، و`order-flow` (رحلة الطلب)، و`requests` (العروض والجولات)، و`tickets-settlement` (التذاكر والتسوية)، و`support`، و`reviews`، و`platform`، و`hardening` (الحماية)، و`live-tracking`، و`consultations`، و`showcase` (مربعات الخريطة). المساعد `harness.ts` بيعمل موكل ومحامي وأدمن.
**ملف جديد لازم يتضاف لسكريبت `test` في `backend/package.json`.**

## 3. ملفات التطبيق (`test`)
`widget_test.dart` (الشاشات)، و`session/` (الدخول والتنقل ورحلة الطلب)، و`api_integration_test.dart`.

## 4. القواعد
- أي ميزة أو إصلاح بيتضاف معاه اختبار، وأي حاجة فيها فلوس لازم اختبار.
- ما تقولش «اتجرب» من غير ما تشغّل الأمر وتكتب النتيجة. واللي ما اتجربش يتكتب.
- الحاجات اللي مش بتتغطى هنا (موبايل حقيقي، والبصمة، والإشعارات، والخريطة على الجهاز) بتتكتب في `CURRENT_STATUS.md` إنها «ما اتجربتش».
