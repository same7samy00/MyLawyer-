# معايير الهندسة

**المرجع الوحيد لطريقة كتابة الكود في المشروع.** آخر تحقق: 2026-11-07. اللي مكتوب هنا هو الموجود فعلًا في الكود، والاستثناءات المعروفة مكتوبة في آخر الملف عشان تتصلّح تدريجيًا. قواعد التصميم والمنتج في `AGENTS.md`.

## 1. قبل أي كود جديد
1. دوّر على حاجة شبهه في المشروع وامشِ على طريقتها ([`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md)).
2. استخدم المكونات والخدمات المشتركة. ما تعملش نمط جديد من غير سبب مكتوب في [`memory/ARCHITECTURE_DECISIONS.md`](memory/ARCHITECTURE_DECISIONS.md).
3. ممنوع مكتبة جديدة من غير موافقة صاحب المشروع.
4. اختبار مع كل تغيير ([`TESTING.md`](TESTING.md))، وتوثيق في نفس الـ commit.

## 2. أدوات الجودة (إجبارية، والفحص التلقائي بيشغّلها)
| الجزء | الأداة | الإعداد |
|---|---|---|
| كل الملفات | الترميز والمسافات ونهاية السطر | `.editorconfig` (UTF-8، ومسافتين، وLF) |
| التطبيق | `flutter analyze` لازم «No issues found!» | `analysis_options.yaml`: `flutter_lints` + قواعد زيادة (single quotes، و`const`، و`final`، وترتيب الـ imports، وimports نسبية، وفواصل آخر السطر) |
| التطبيق | التصليح الآلي | `dart fix --apply` |
| الخادم | `npx tsc --noEmit` | `tsconfig.json`: `strict`، ومفيش متغيرات أو parameters مش مستخدمة، وكل مسار في الدالة بيرجع قيمة |
| الكل | الفحص التلقائي على GitHub | `.github/workflows/checks.yml` |

## 3. الأسماء
| الحاجة | الطريقة | مثال |
|---|---|---|
| ملفات Dart | `snake_case` | `map_lawyer_loader.dart` |
| classes وwidgets | `PascalCase` | `MapLawyerLoader` |
| ملفات الخادم | `camelCase` أو كلمة واحدة | `pushService.ts`، `routes.ts` |
| المسارات | جمع وkebab-case تحت `/api/v1` | `/lawyers/map`، `/consultations/:id/contact` |
| جداول القاعدة وأعمدتها | `snake_case` جمع | `service_orders.payout_status` |
| الـ migrations | رقم من 3 خانات + وصف | `035_lawyer_showcase.sql` |
| الفروع | `claude/<المهمة>` أو `gemini/<المهمة>` | `claude/orders-card` |

## 4. التطبيق (Flutter)
- **الطبقات:** الشاشة (`features/`) ← المستودع (`data/repositories/`) ← `ApiService`. **الشاشة ما بتكلمش الخادم مباشرة أبدًا.**
- **الرد:** كل طلب بيرجع `ApiResponse<T>` (`success` و`data` و`error` و`isConnectivityError`). الشاشة بتعرض `error` زي ما هو لأنه جاي بالعربي من الخادم.
- **أول رسم:** من المحفوظ (`SavedData.peek` أو `peek...` في المستودع)، والخادم بيحدّث في الخلفية. ممنوع جزء يظهر متأخر ويزق اللي تحته.
- **التحديث:** المتغير بالخط المباشر (`LiveUpdates`)، والثابت مرة للصفحة. ممنوع `Timer` بيسأل الخادم من غير سبب.
- **المكونات:** من `core/widgets` (`AppCard`، و`AppButton`، و`AppSheetHeader`، و`AppStateMessage`، و`AppLoader`...). الألوان من `AppColors`، والحواف من `AppTheme`.
- **الملف:** شاشة كبيرة تتقسم بـ `part` لملفات `_views` و`_widgets` و`_map` زي `tracking_screen*.dart`.
- **التنظيف:** أي `Timer` أو `Controller` أو listener يتقفل في `dispose`.

## 5. الخادم (Fastify)
- **الوحدة:** `modules/<الاسم>/routes.ts` للمسارات، و`service.ts` للمنطق المشترك، و`admin.ts` لمسارات الإدارة. وتتسجل في `app.ts`.
- **الرد:** دايمًا `{ success: true, data?, message? }` أو `{ success: false, error }`، والرسالة بالعربي.
- **الأخطاء:** `throw new HttpError(status, 'رسالة')`. أي حاجة تانية بتبقى 500 برسالة عامة وبتتسجل (`app.ts`).
- **الصلاحية:** `requireAuth([...])` على المسار نفسه، مش في الواجهة.
- **الفلوس والحالات:** جوه `withTransaction`، مع قفل الحساب والطلب (`FOR UPDATE`)، والإشعار والتغيير المباشر جوه نفس المعاملة.
- **الإدخال:** تحقق صريح من كل قيمة (رقم، وطول، و`UUID_PATTERN`)، والنص بـ `sanitizeText`.
- **الـ SQL:** parameters دايمًا (`$1`)، وممنوع دمج قيم في النص.
- **الكاش:** في الذاكرة بمدة واضحة ومع اختبار (`lawyers/showcase.ts`)، ومن غير خدمات زيادة.

## 6. لوحة التحكم
JS عادي من غير مكتبات: صفحة لكل قسم في `public/admin/js/pages/`، والمكونات المشتركة في `components.js`، والنوافذ في `windows.js`. ممنوع `innerHTML` (الـ CSP بيمنعه). الحواف 5px. وأي ملف جديد يتضاف لقايمة `admin/panel.ts`.

## 7. الـ commits والتوثيق
- رسالة الـ commit بالإنجليزي: `feat:` أو `fix:` أو `docs:` أو `ci:` أو `chore:` أو `style:` + إيه اللي اتغير.
- التوثيق والذاكرة (`docs/memory/`) بيتحدثوا في نفس الـ commit.

## 8. استثناءات معروفة (تتصلّح تدريجيًا)
| الاستثناء | فين | الخطة |
|---|---|---|
| SQL جوه ملفات المسارات | أغلب `modules/*/routes.ts` | ARCH-01: نقله لـ `service.ts` ملف ملف بالاختبارات |
| 25 `console.log/error` بدل لوجر Fastify | `backend/src` | توحيده على `request.log` أو `fastify.log` |
| 20 عملية `Future` بتتساب من غير انتظار | `lib/` | مراجعة كل واحدة، وتفعيل `unawaited_futures` |
| أسماء ملفات الخادم مش موحدة 100% | `src/services` | تفضل زي ما هي، والجديد يمشي على الجدول |
| مفيش أداة تنسيق للخادم (Prettier/ESLint) | `backend` | محتاجة موافقة على مكتبة تطوير جديدة |
