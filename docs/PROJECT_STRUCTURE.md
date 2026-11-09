# بنية المشروع: كل حاجة فين

**آخر تحقق:** 2026-11-07. إزاي الأجزاء بتكلم بعض في `docs/engineering/SYSTEM_MAP.md`، والقواعد في `AGENTS.md`.

## الجذر
| المسار | فيه إيه |
|---|---|
| `lib/` | تطبيق Flutter (موكل ومحامي في تطبيق واحد) |
| `test/` | اختبارات التطبيق، والخادم الوهمي `helpers/fake_backend.dart` |
| `assets/` | الخطوط والصور وملف مناطق مصر `data/egypt_places.json` |
| `android/` و`ios/` | إعدادات المنصات (الملفات السرية متجاهلة) |
| `backend/` | الخادم ولوحة التحكم والموقع وسكريبتات الخرايط والرفع |
| `docs/` | التوثيق، والفهرس في `docs/README.md` |
| `.github/workflows/` | `deploy.yml` (الرفع) و`checks.yml` (الفحص التلقائي) |
| `.access/` | بيانات الدخول (متجاهل، ممنوع يترفع) |

## التطبيق `lib/`
| المسار | المسؤولية |
|---|---|
| `main.dart` | البداية: RTL، وقراية المحفوظ (`SavedData.preload`)، والبصمة، والإشعارات |
| `core/config` و`core/constants` و`core/theme` | الإعدادات والألوان والخطوط والثيم |
| `core/services/` | منطق مش مرتبط بشاشة: الاتصال بالخادم (`api_service`)، والدخول، والموقع، والخط المباشر (`live_updates`)، والإشعارات، والحفظ، وتحميل محامين الخريطة (`map_lawyer_loader`) |
| `core/widgets/` | المكونات المشتركة (الكروت، والأزرار، والشيتات، والهيدر، والبار السفلي، وكروت الخريطة) |
| `data/models/` | شكل البيانات اللي جاية من الخادم |
| `data/repositories/` | **المكان الوحيد** اللي بيطلب من الخادم، ومعاه الحفظ والقراية الفورية (`peek`) |
| `features/<الميزة>/` | الشاشات: `auth`، و`client`، و`lawyer`، و`urgent_service` («محاميك حالاً»)، و`consultation`، و`support`، و`notifications`، و`account` |

## الخادم `backend/`
| المسار | المسؤولية |
|---|---|
| `src/server.ts` و`src/app.ts` | التشغيل والـ workers، وتسجيل الوحدات والحماية |
| `src/config/` | قراية `.env` والتحقق منها |
| `src/database/` | الاتصال والمعاملات، وتشغيل الـ migrations |
| `src/modules/<الوحدة>/` | `routes.ts` (المسارات) و`service.ts` (المنطق) و`admin.ts` (مسارات الإدارة): `auth`، و`users`، و`lawyers` (والخريطة `showcase.ts`)، و`requests` (العروض)، و`orders`، و`lifecycle` (القواعد والمواعيد والـ sweep)، و`wallet`، و`support`، و`consultations`، و`notifications`، و`admin` |
| `src/services/` | خدمات مشتركة: الإيميل، والإشعارات (FCM)، والخط المباشر |
| `src/utils/` | الحماية والملفات والأخطاء |
| `migrations/` | تغييرات قاعدة البيانات بالترتيب، وبتشتغل لوحدها |
| `public/admin/` | لوحة التحكم (JS عادي): `js/pages/` صفحة لكل قسم، و`components.js` و`windows.js` مشتركين |
| `public/site/` | الموقع العام والسياسات |
| `scripts/` | معاينة اللوحة محليًا، وتوليد المحافظات، واختبار الحمل |
| `tests/` | اختبارات الخادم (`docs/TESTING.md`) |
| `deploy.sh` | الرفع على السيرفر (`docs/DEPLOYMENT.md`) |

## إضافة ميزة جديدة
1. **الخادم:** وحدة في `src/modules/<الاسم>/` (المسارات في `routes.ts`، والمنطق في `service.ts`)، وتتسجل في `app.ts`، وأي جدول جديد migration برقم جديد، واختبار في `tests/` ويتضاف لسكريبت `npm test`.
2. **التطبيق:** model في `data/models`، ومستودع في `data/repositories` بقراية فورية من `SavedData`، والشاشات في `features/<الاسم>/` من المكونات المشتركة.
3. **اللوحة:** صفحة في `public/admin/js/pages/` وتتضاف لقايمة `admin/panel.ts`.
4. **التوثيق:** `API_DOCUMENTATION.md`، و`CHANGELOG.md`، والملف ده لو البنية اتغيرت.
