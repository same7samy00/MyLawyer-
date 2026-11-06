# خريطة النظام

**الغرض:** إيه الموجود فعلًا، وإزاي الأجزاء بتكلم بعض. **آخر تحقق:** 2026-11-06. **الحالة:** VERIFIED من الكود، والسيرفر RUNTIME VERIFIED بالقراءة.

## 1. المكونات

| المكون | المكان | التقنية | نقطة الدخول |
|---|---|---|---|
| تطبيق الموبايل (موكل ومحامي في تطبيق واحد) | `lib/` | Flutter 3.24.3، أندرويد وآيفون | `lib/main.dart` ثم `features/auth/session_router.dart` |
| الخادم | `backend/src` | Node 20، Fastify 5، TypeScript، `pg` | `backend/src/server.ts` |
| لوحة التحكم | `backend/public/admin` | JS عادي من غير مكتبات، والخادم بيقدمها | `GET /api/v1/admin-panel` (`modules/admin/panel.ts`) |
| الموقع العام والسياسات | `backend/public/site` | HTML ثابت | Nginx على `/` |
| قاعدة البيانات | `backend/migrations` (30 ملف) | PostgreSQL 16 | `src/database/migrate.ts` بيشتغل مع كل تشغيل |
| الخرائط والطرق | `backend/map-services` | Docker: tileserver وOSRM | Nginx على `/map/v2` و`/osrm/` |
| الرفع التلقائي | `.github/workflows/deploy.yml` و`backend/deploy.sh` | GitHub Actions، والـ runner على السيرفر | push على `main` يغيّر `backend/**` |
| الاختبارات | `test/` (Flutter) و`backend/tests` | `flutter test`، و`node --test` مع PGlite | - |

خدمات خارجية: Firebase Cloud Messaging للإشعارات (`services/pushService.ts`)، وPostfix محلي للإيميل (`services/emailService.ts`). مفيش بوابة دفع (NOT IMPLEMENTED).

## 2. الصورة العامة

```mermaid
flowchart LR
  subgraph Phone[الموبايل]
    App[Flutter app]
  end
  Admin[متصفح الإدارة]
  subgraph VPS[Contabo VPS - Ubuntu 24.04]
    Nginx[Nginx :443]
    subgraph Node[mylawyer-backend - systemd]
      Primary[العملية الرئيسية: migrations + sweep كل 3 ثواني]
      W1[worker 1]
      W2[worker 2]
      W3[worker 3]
    end
    PG[(PostgreSQL 16)]
    OSRM[OSRM :5000]
    Tiles[tileserver :3000]
    Mail[Postfix + OpenDKIM]
    Files[(storage/public و storage/private_docs)]
  end
  FCM[Firebase FCM]

  App -- HTTPS REST + SSE --> Nginx
  Admin -- HTTPS --> Nginx
  Nginx -- /api --> W1 & W2 & W3
  Nginx -- /map/v2 --> Tiles
  Nginx -- /osrm --> OSRM
  Nginx -- /uploads --> Files
  W1 & W2 & W3 --> PG
  Primary --> PG
  W1 -- وقت الطريق --> OSRM
  W1 -- push --> FCM
  W1 -- OTP --> Mail
  PG -- LISTEN/NOTIFY --> W1 & W2 & W3
```

## 3. مسار الطلب الواحد جوه الخادم

`Nginx` ← `app.ts` (helmet، cors، rate-limit بالحساب أو العنوان، multipart، jwt) ← `requireAuth` في `onRequest` ← فحص الإيقاف في `preHandler` (استعلام على `users` مع كل طلب فيه تسجيل دخول) ← الـ handler في `modules/<الوحدة>` ← `query` أو `withTransaction` من `database/index.ts` ← الرد `{ success, data | error }`. أي `HttpError` بيرجع رسالة عربية، وأي خطأ 500 بيتسجل ويرجع رسالة عامة (`app.ts` السطر 34).

ما فيش طبقة service أو repository منفصلة في أغلب الوحدات: الـ SQL مكتوب جوه الـ routes، والمنطق المشترك في `modules/lifecycle` و`modules/requests/service.ts` و`modules/support/service.ts`.

## 4. الدخول والجلسات

```mermaid
sequenceDiagram
  participant A as App
  participant S as Server
  participant DB as PostgreSQL
  A->>S: POST /auth/register
  S->>DB: users (pending_email_verification) + OTP مشفر SHA-256
  S-->>A: 201، والكود بيتبعت بالإيميل
  A->>S: POST /auth/verify-otp
  S->>DB: status = active
  A->>S: POST /auth/login
  S->>DB: argon2id verify + user_sessions(refresh hash)
  S-->>A: accessToken (JWT 15 دقيقة) + refreshToken (30 أو 60 يوم)
  A->>S: أي طلب مع Bearer
  A->>S: POST /auth/refresh (تدوير: القديم يتلغي)
```

- الأدوار: `client` و`lawyer` و`admin`، ومكتوبة جوه الـ JWT. تغيير الدور بيتأخر لحد 15 دقيقة، لكن الإيقاف بيتطبق فورًا من الـ `preHandler`.
- التطبيق بيحفظ الجلسة في `SharedPreferences` (مش مشفرة)، وده متسجل في `TASKS.md`.
- اللوحة بتحفظ الجلسة في `sessionStorage`، وبيحميها CSP صارم (`panel.ts`)، ومفيش `innerHTML` في كود اللوحة.

## 5. رحلة «محاميك حالاً» (الحالية)

```mermaid
stateDiagram-v2
  [*] --> OPEN: POST /requests (أقرب 10 جوه 50 كم)
  OPEN --> OPEN: جولة مفيهاش عروض = الـ 10 اللي بعدهم (جولتين). وزرار «بحث جديد» بيبعت للمجموعة اللي بعدها
  OPEN --> SELECTED: الموكل يختار عرض
  OPEN --> NO_OFFERS: مفيش محامين
  OPEN --> EXPIRED: 5 دقايق من غير اختيار
  OPEN --> CANCELLED: الموكل لغى
  SELECTED --> ACCEPTED: يتعمل service_order
  ACCEPTED --> ACTIVE: confirm-payment (رصيد أو DIRECT)
  ACCEPTED --> PAYMENT_EXPIRED: 10 دقايق
  ACTIVE --> ACTIVE: arrive (50 متر) / postpone / keep-waiting
  ACTIVE --> COMPLETED: complete (أتعاب HELD لمدة 24 ساعة)
  ACTIVE --> CANCELLED: إلغاء الموكل أو اعتذار المحامي (المبلغ يرجع رصيد)
  ACTIVE --> REFUNDED: مهلة بدون وصول (sweep)
  COMPLETED --> COMPLETED: تذكرة = FROZEN، وقرار الإدارة = تسوية
```

المسار القديم (`POST /orders` لمحامي واحد مع سعر عشوائي من `client_problem_prices`) لسه شغال للنسخ القديمة من التطبيق، والتطبيق الحالي ما بيستخدموش. الحالة **DEPRECATED**.

## 6. الفلوس (دفتر حسابات من غير أرصدة مخزنة)

- **رصيد الموكل** = `SUM(client_credits.amount)`.
- **رصيد المحامي المتاح** = `SUM(service_orders.payout_amount WHERE payout_status = 'AVAILABLE')` + `SUM(lawyer_adjustments.amount)` (`wallet/routes.ts` `spendableBalance`).
- **حالات الأتعاب:** `HELD` بعد الإنهاء، وبعد 24 ساعة `AVAILABLE`، و`FROZEN` بالتذكرة أو الإدارة، و`REFUNDED`.
- **العمولة والضريبة** بيتقفلوا على الطلب ساعة إنشائه، وصافي المحامي في `lawyerShare()` (`lifecycle/service.ts`).
- **الأقفال:** كل خطوة فيها فلوس بتقفل الحساب (`SELECT ... FROM users FOR NO KEY UPDATE`) والطلب (`lockOrder`، `FOR UPDATE`).
- **مفيش سحب لفلوس حقيقية** (NOT IMPLEMENTED)، ومفيش تحصيل حقيقي.

## 7. التحديث الحي

- `GET /api/v1/events` خط SSE لكل جهاز، بحد 3 خطوط للشخص، ونبضة كل شوية (`services/liveUpdates.ts`).
- أي تغيير بيتكتب في `change_log` وبيتبعت بـ `pg_notify` جوه نفس المعاملة، فمش بيوصل غير بعد الحفظ. وكل worker بيسمع بـ `LISTEN`.
- الجهاز اللي الخط بتاعه قطع بيطلب `GET /events/since?after=N`، ولو فاته أكتر من 200 تغيير أو الأرشيف اتمسح (بعد يومين) بيحمّل كل حاجة من الأول.
- **الإشعارات المهمة** بتروح كمان لـ FCM، والهادية (قايمة `QUIET_TITLES`) بتفضل جوه التطبيق بس.

## 8. المهام الزمنية

`sweepLifecycle()` (`lifecycle/sweep.ts`) بيشتغل في العملية الرئيسية بس كل 3 ثواني، والجولة الجاية ما بتبدأش قبل ما اللي قبلها تخلص. فيه 12 خطوة: إقفال الطلبات اللي ما اتردش عليها، وتقديم جولات العروض، وإقفال اللي ما اتدفعش، وفك الإيقاف، وإخفاء المحامي الساكت 10 دقايق، وتنظيف الإشعارات (30 يوم) و`change_log` (يومين)، والتذكيرات، ورد الفلوس عند عدم الوصول، وتحرير الأتعاب المحجوزة، وتذكير التقييم.

## 9. السيرفر (قراءة 2026-11-06)

| البند | الوضع |
|---|---|
| المنافذ المفتوحة للخارج | 22 و80 و443 (UFW). الخادم على `127.0.0.1:4000`، وPostgreSQL وOSRM وtileserver محليين بس |
| العمليات | `WEB_WORKERS=3`، و`DB_POOL_MAX=15` لكل worker (يعني 60 اتصال كحد أقصى من 120 مسموحين) |
| الذاكرة والقرص | 7.8 جيجا رام منها 3.3 مستخدمة، وSwap 4 جيجا، والقرص 25% |
| Nginx | gzip شغال، وHSTS شغال، وحدود طلبات للدخول والخرائط والطرق |
| النسخ الاحتياطية | `deploy.sh` بيعمل نسخة مع كل رفع، على نفس السيرفر بس. مفيش نسخة يومية ولا نسخة بره السيرفر |
| SSH | بالمفتاح بس |
