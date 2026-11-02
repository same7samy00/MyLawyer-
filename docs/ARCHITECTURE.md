# 🏗️ Architecture & Technical Specification - My Lawyer

## 1. نظرة عامة على المنصة (Platform Architecture Overview)
**My Lawyer** هي منصة قانونية متكاملة عالية الاعتمادية مبنية بإطار عمل Flutter وموجهة للهواتف الذكية (Android و iOS).  
تعتمد المنصة على معمارية معيارية نظيفة (Modular Clean Architecture) تفصل واجهات المستخدم عن منطق الأعمال والخدمات، وتدعم طرفي التعامل: **العميل والمحامي**.

---

## 2. جدول توافقية أنظمة التشغيل (Mobile Compatibility Matrix)

| المنصة | أقل إصدار مدعوم (Min SDK) | الإصدار المستهدف (Target SDK) | حالة الدعم |
|---|---|---|---|
| **Android** | Android 5.0 (API 21) | Android 15/16 (API 35/36) | مدعوم ومُختبر على أجهزة حقيقية |
| **iOS** | iOS 12.0 | iOS 18.0+ | متوافق ومعتمد بالكامل |

---

## 3. طبقات المشروع وهيكلية الحزم (Layered Architecture)

```text
lib/
├── core/
│   ├── constants/
│   │   ├── app_colors.dart         # لوحة الألوان الحصرية للمنصة
│   │   └── map_config.dart         # إعدادات ونقاط نهاية خوادم الخرائط VPS
│   ├── theme/
│   │   └── app_theme.dart          # ثيم الحواف (12px للأزرار و 7px للكروت) وعائلة خط ThmanyahSans
│   ├── services/
│   │   ├── api_service.dart        # عميل HTTP المركزي للاتصال بالخادم والـ JWT والـ Interceptors
│   │   ├── auth_service.dart       # خدمة المصادقة والتسجيل وتشفير SHA-256 والتحقق من البريد
│   │   ├── location_service.dart   # خدمة فحص الصلاحيات وتحديد الموقع الفردي
│   │   ├── geo_naming_service.dart # خدمة التحويل العكسي للإحداثيات إلى اسم المدينة والمحافظة
│   │   └── routing_service.dart    # المسافة والوقت وتقدير الزحمة
│   └── widgets/
│       ├── app_bottom_bar.dart     # شريط التنقل السفلي الموحد (4 تبويبات)
│       ├── app_button.dart         # زر المنصة الموحد 12.0px مع حماية التحميل والتفاعل الحركي
│       ├── app_pressable.dart      # ويدجت التفاعل اللمسي (Micro-Scale 0.975 وحماية Debounce)
│       ├── app_header.dart         # الهيدر العلوي العام الموحد مع التنقل والأيقونات المباشرة
│       ├── app_card.dart           # كرت العرض الموحد مع حد شرط رفيع (0.9px) وظل خفيف جداً
│       ├── status_badge.dart       # شارة الحالة الموحدة بنص مباشر ونقطة لونية
│       ├── lawyer_profile_summary.dart # ملخص ملف المحامي الموحد لبوتن شيت الخريطتين
│       └── password_strength_widget.dart # مؤشر قوة كلمة المرور وحالة المعايير
├── features/
│   ├── auth/                        # البداية والدخول والتسجيل وتوجيه الجلسة
│   ├── client/                      # حاوية الموكل وتبويباته الأربعة
│   ├── lawyer/                      # حاوية المحامي وتبويباته الأربعة
│   ├── notifications/               # صفحة الإشعارات
│   └── urgent_service/              # رحلة «محاميك حالاً»: المشكلة والخريطة والدفع
└── main.dart                       # نقطة انطلاق التطبيق وتهيئة RTL
```

---

## 3.1 دورة الجلسة والتنقل (Session & Navigation)

- **`SessionRouter`** (`lib/features/auth/session_router.dart`) هو المرجع الوحيد لتوجيه المستخدم، وكل انتقال بين الدخول والخروج يمسح مكدس الصفحات.
- **فتح التطبيق:** `SplashScreen` تستدعي `AuthService.restoreSession()` مع الفيديو، ثم تنتقل مرة واحدة: دخول، رئيسية الموكل، تحديد الموقع، رئيسية المحامي، حالة الاعتماد، أو إعادة المحاولة.
- **تجديد الجلسة:** `ApiService` يعالج 401 بطلب `/auth/refresh` واحد مهما تزامنت الطلبات. الجلسة تُمسح فقط عند رفض الخادم لها، ولا تُمسح عند انقطاع الاتصال.
- **حالة الاتصال:** `ApiService.isServerReachable` تغذي `ConnectionGate`، وعند الانقطاع تظهر صفحة كاملة لحد ما الاتصال يرجع.
- **البيئات:** `AppConfig` يقيّد Release بخادم الإنتاج، والبيئات الأخرى تحدد خادمها عبر `--dart-define`.
- **الأزرار:** `AppPressable` للضغط الرمادي، و`AppButton` يعرض التحميل فقط عندما يعيد إجراؤه `Future`.

## 3.2 دورة الطلب والأموال

- **الحالات:** `PENDING` (دقيقتان للرد) ثم `ACCEPTED` (10 دقايق للدفع) ثم `ACTIVE` ثم `COMPLETED` بكود الموكل فقط وبعد تسجيل وصول المحامي. الحالات الأخرى: `NO_RESPONSE`، `PAYMENT_EXPIRED`، `EXPIRED` بعد 24 ساعة من الدفع، `REFUNDED`، `REJECTED`، `CANCELLED`.
- **السعر:** الخادم يحدده من `problem_prices` ويثبته في `client_problem_prices`، والموكل يوافق عليه قبل إرسال الطلب عبر `/orders/quote`.
- **نسبة المنصة:** تُثبت في الطلب عند إنشائه (`commission_percent`, `lawyer_amount`). المحامي يرى الصافي والموكل يرى السعر الكامل. عند الرد الجزئي تُحسب النسبة على الباقي، وعند الرد الكامل لا تأخذ المنصة شيئاً.
- **الأتعاب (`payout_status`):** `HELD` لمدة 24 ساعة ثم `AVAILABLE`. الشكوى تحولها إلى `FROZEN`، والرد الكامل إلى `REFUNDED`.
- **الرصيد:** المبالغ المرتجعة في `client_credits`، تُستخدم في الدفع ولا تُسحب.
- **الحدود:** طلب مفتوح واحد للموكل ومهمة واحدة للمحامي. طلبان بلا رد يحولان المحامي لغير متاح، و3 اعتذارات أو 3 شكاوى مثبتة خلال 30 يوم توقفه أسبوع، وإثبات رفض الكود مرتين يوقف الموكل.
- **المهام الزمنية:** `sweepLifecycle` في `backend/src/modules/lifecycle/service.ts` تعمل كل 10 ثوانٍ.
- **الإشعارات:** `NotificationCenter` يحدث العدادات كل 15 ثانية للمحامي و60 ثانية للموكل والتطبيق ظاهر فقط. إشعارات الهاتف والتطبيق مغلق مضافة عبر Firebase، ولم تُجرب فعلياً بعد.

## 4. نظام التصميم والواجهات (Design System & Tokens)

1. **الخطوط:**
   - خط **`flat-jooza`** (جذور مسطح) للنصوص، مع أرقام إنجليزية من `assets/fonts/app-digits.ttf`.
   - عائلة خط **`Nunito`** لنص العلامة التجارية الإنجليزي **"My Lawyer"** لإضفاء لمسة ناعمة وانسيابية غير حادة.
2. **الألوان المعتمدة (`AppColors`):**
   - الأساسي: `#1D4ED8`
   - الداكن الرئيسي: `#0F172A`
   - الخلفية: `#F8FAFC`
   - الحدود: `#E2E8F0`
   - النجاح: `#16A34A`
   - الطوارئ والتنبيه: `#DC2626`
3. **قاعدة الحواف الدائرية (Border Radii Policy):**
   - **كافة العناصر القياسية:** حقول الإدخال، الأزرار، الكروت، الحوارات (Dialogs)، شارات الحالة، وأزرار الخريطة تلتزم بحواف `7.0px` (`BorderRadius.circular(7.0)`).
   - **النوافذ السفلية (Bottom Sheets):** حواف علوية مستديرة بانسيابية بمقدار `20.0px` (`BorderRadius.vertical(top: Radius.circular(20.0))`).
4. **تخطيط الواجهات والتنقل (Layout & Navigation):**
   - **إلغاء الهيدر العلوي تماماً** عبر كافة الشاشات (`appBar: null`).
   - شريط تنقل سفلي قياسي (`AppBottomBar`) يدمج التبويبات الأربعة: الرئيسية، الطلبات، المحفظة، الحساب.

---

## 5. الأذونات ونظام الموقع (Permissions & Geolocation)

### أذونات نظام أندرويد (`AndroidManifest.xml`):
- `android.permission.INTERNET`: للاتصال بالخادم وخرائط OpenStreetMap.
- `android.permission.ACCESS_FINE_LOCATION`: لتحديد الموقع الدقيق للعميل.
- `android.permission.ACCESS_COARSE_LOCATION`: لتحديد الموقع التقريبي.

### أذونات نظام iOS (`Info.plist`):
- `NSLocationWhenInUseUsageDescription`: شرح طلب تحديد الموقع لتوفير أقرب محامٍ متاح.
- `NSLocationAlwaysAndWhenInUseUsageDescription`: للاستخدام المستمر عند الحاجة.

---

## 6. البنية التحتية والخدمات السحابية (Cloud & VPS Infrastructure)
- **الخادم السحابي المستقل (VPS):** خادم مخصص على Contabo (ألمانيا) بعنوان IP `13.140.141.32`.
- **محرك التوجيه وحساب المسارات (OSRM):** يعمل عبر Docker على المنفذ المحلي `5000`، ويمر عبر Nginx على `/osrm/` بحد طلبات، ويحسب الوقت والمسافة فقط.
- **خادم الخرائط الذاتي (TileServer GL):** يرسم خريطة مصر العربية من `egypt.pmtiles` على المنفذ المحلي `3000`، ويخدمها Nginx من كاش `/map/v1`.
- **أسماء المناطق:** ملف `assets/data/egypt_places.json` داخل التطبيق، ولا يحتاج طلبات للسيرفر.
- **الدومين والتشفير:** `https://my-lawyer.online` بشهادة Let's Encrypt تتجدد تلقائياً.
- **الإشعارات:** Firebase مشروع `my-lawyer-51a6c` عبر `pushService.ts` وقناة `orders` عالية الأولوية.
- **نظام الخريطة:** راجع [`docs/GPS_SYSTEM.md`](./GPS_SYSTEM.md).
- الدليل الفني المفصل: يرجى مراجعة [`docs/VPS_SERVER_AND_MAPS.md`](./VPS_SERVER_AND_MAPS.md).

## 7. قواعد واستقرار البرمجيات (Quality & Maintenance Directives)
- يمنع استخدام بيانات وهمية (Mock Data) كبديل للمنطق المستقر.
- كود خالٍ تماماً من أي تحذيرات (`flutter analyze` يخرج دائماً بـ `No issues found!`).
- تغطية واجهات ومكونات التطبيق باختبارات مؤتمتة (`flutter test`).
