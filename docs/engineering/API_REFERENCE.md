# مرجع مسارات الخادم

**الغرض:** كل مسار موجود فعلًا، ومين محمي، ومين بيستخدمه. **آخر تحقق:** 2026-11-06.
**المصدر:** استخراج آلي من `fastify.get/post/put/patch/delete` في `backend/src`، ومقارنته بطلبات `ApiService` في `lib/` وطلبات اللوحة في `backend/public/admin/js`. **الحالة:** VERIFIED.

كل المسارات تحت `/api/v1`. الرد دايمًا `{ success: true, data?, message? }` أو `{ success: false, error }`. التفاصيل الأقدم للطلبات والردود في `docs/API_DOCUMENTATION.md`.

**الصلاحية:** عام = من غير دخول. دخول = أي حساب. والأدوار مكتوبة لو المسار بيرفض غيرها.
**المستخدم:** App = التطبيق، Panel = لوحة التحكم، **—** = مفيش حد بيستخدمه دلوقتي.

## عام وتحديث حي (`app.ts`)
| المسار | الصلاحية | المستخدم | ملاحظة |
|---|---|---|---|
| `GET /health` | عام | Nginx و`deploy.sh` | بيرد UP أو DEGRADED بس. و`/health` من غير `/api/v1` مش واصل من Nginx (404) |
| `GET /events` | دخول | App وPanel | خط SSE |
| `GET /events/since?after=` | دخول | App | استرجاع اللي فات |

## الدخول (`modules/auth/`: `register.ts` للتسجيل والتفعيل، و`session.ts` للدخول والتجديد والخروج، و`password.ts` للاستعادة)، وعليه حد Nginx `auth_requests` وحد الخادم 120 في الدقيقة للعنوان
| المسار | الصلاحية | المستخدم |
|---|---|---|
| `POST /auth/register` | عام | App |
| `POST /auth/verify-otp` | عام | App |
| `POST /auth/resend-otp` | عام | App |
| `POST /auth/login` | عام | App وPanel |
| `POST /auth/refresh` | refresh token | App وPanel |
| `POST /auth/logout` | refresh token | App |
| `POST /auth/forgot-password` | عام | App |
| `POST /auth/reset-password` | عام | App |

## المستخدم (`modules/users/routes.ts`)
| المسار | الصلاحية | المستخدم | ملاحظة |
|---|---|---|---|
| `GET /users/me` | دخول | App (4 شاشات منفصلة) وPanel | انظر PERF-04 |
| `PATCH /users/me` | دخول | **—** | بيعدّل اسم المحامي بس، ولو موكل بيرد «تم» من غير ما يغير حاجة |
| `POST /users/me/change-password` | دخول | **—** | مفيش شاشة لتغيير كلمة المرور في التطبيق |
| `POST /users/me/profile-photo` | دخول | App | |

## المحامين (`modules/lawyers/routes.ts`)
| المسار | الصلاحية | المستخدم | ملاحظة |
|---|---|---|---|
| `GET /lawyers/map` | **عام** | App | مربعات الخريطة، كل المحامين المعتمدين، كاش 5 دقايق في الذاكرة |
| `GET /lawyers/top` | **عام** | App | أعلى 20 في المحافظة، كاش 5 دقايق |
| `GET /routes` و`/routes/place` | مسجل | App | الطريق بالزحمة واسم المكان من TomTom، بإجابة مشتركة للأماكن القريبة |
| `GET /lawyers/:id/reviews` | عام | App | الاسم المختصر بس |
| `GET /lawyers/me` | lawyer, admin | App | |
| `POST /lawyers/me/urgent-terms` | lawyer, admin | App | |
| `POST /lawyers/me/availability` | lawyer, admin | App | |
| `POST /lawyers/me/location` | lawyer, admin | App | |
| `POST /lawyers/me/documents` | lawyer, admin | App (بعد التسجيل) | التخزين في `private_docs` |
| `GET /lawyers/documents/:id` | صاحب المستند أو admin | Panel | |
| `POST /lawyers/me/reviews/:reviewId/report` | lawyer, admin | App | |

## طلبات العروض (`modules/requests/routes.ts`)، المسار الحالي
| المسار | الصلاحية | المستخدم |
|---|---|---|
| `GET /requests/range` | دخول | App |
| `POST /requests` | client | App |
| `GET /requests/incoming` | lawyer | App |
| `POST /requests/:id/offer` | lawyer وصله الطلب، طول ما الطلب مفتوح | App |
| `POST /requests/:id/offer/withdraw` | صاحب العرض | App |
| `GET /requests/:id` | صاحب الطلب | App |
| `POST /requests/:id/cancel` | صاحب الطلب | App |
| `POST /requests/:id/search` | صاحب الطلب | App |
| `POST /requests/:id/offers/:offerId/select` | صاحب الطلب | App |

## الطلبات (`modules/orders/*`)
| المسار | الصلاحية | المستخدم | ملاحظة |
|---|---|---|---|
| `POST /orders/quote` | دخول | **—** | DEPRECATED، للنسخ القديمة |
| `POST /orders` | دخول | **—** | DEPRECATED، للنسخ القديمة |
| `GET /orders` و`GET /orders?id=` | دخول (طلباته بس) | App | admin بيشوف كل الطلبات |
| `GET /orders/:id` | طرف في الطلب | App | |
| `GET /orders/wallet/me` | دخول | App | ملخص محفظة المحامي |
| `POST /orders/:id/accept` و`/reject` | المحامي | App | ليهم لازمة مع طلبات `PENDING` من المسار القديم بس، لأن الطلبات الجديدة بتبدأ `ACCEPTED` |
| `POST /orders/:id/confirm-payment` | الموكل | App | `method: 'wallet'` أو من غيره = `DIRECT`. انظر SEC-01 |
| `POST /orders/:id/arrive` | المحامي | App | 50 متر من مكان الطلب أو من آخر نقطة للموكل |
| `POST /orders/:id/position` | طرف في الطلب | App | التتبع اللحظي من الدفع لحد الوصول |
| `POST /orders/:id/keep-waiting` | الموكل | App | |
| `POST /orders/:id/postpone` | المحامي بعد الوصول | App | من غير سبب ولا ميعاد |
| `POST /orders/:id/resume` | المحامي | App | إلغاء التأجيل |
| `POST /orders/:id/complete` | المحامي بعد الوصول | App | |
| `POST /orders/:id/cancel` | طرف أو admin | App | |
| `POST /orders/:id/withdraw` | المحامي بعد الدفع | App | مخالفة على المحامي |
| `POST /orders/:id/review` و`PUT` | الموكل | App | |

## المحفظة (`modules/wallet/routes.ts`)
| المسار | الصلاحية | المستخدم |
|---|---|---|
| `GET /wallet/recipient?phone=` | دخول | App |
| `GET /wallet/limits` | دخول | **—** |
| `GET /wallet/payments` | دخول | App |
| `POST /wallet/transfer` | دخول | App |

## الدعم الفني (`modules/support/routes.ts`)
| المسار | الصلاحية | المستخدم |
|---|---|---|
| `GET /support/tickets` | client, lawyer | App |
| `POST /support/tickets` | client, lawyer | App |
| `GET /support/tickets/:id` | صاحب التذكرة | App |
| `POST /support/tickets/:id/messages` | صاحب التذكرة | App |
| `GET /support/attachments/:id` | صاحب التذكرة أو admin | App وPanel |

## الإشعارات (`modules/notifications/routes.ts`)
`GET /notifications` و`GET /notifications/summary` و`POST /notifications/read` و`/read-all` و`/device-token` و`/device-token/remove`. كلهم بالدخول، والتطبيق بيستخدمهم كلهم.

## الإدارة (`modules/admin/*` و`modules/support/admin.ts`)، كلها `admin` بس، وبتستخدمها Panel
`GET /admin/overview` و`/search` و`/users` و`/users/:id` و`/orders` و`/orders/:id` و`/orders/:id/settlement` و`/reviews` و`/reviews/reported` و`/prices` و`/tax` و`/urgent-applications` و`/money` و`/actions` و`/support` و`/support/:id`.
`POST /admin/users/:id/status` و`/users/:id/balance` و`/users/:id/warnings` و`/warnings/:id/revoke` و`/strikes/:id/revoke` و`/orders/:id/settle` و`/orders/:id/freeze` و`/commission` و`/tax` و`/urgent-applications/:id/decision` و`/reviews/:id/moderate` و`/support/:id/reply` و`/note` و`/transfer` و`/close`، و`PUT /admin/prices`.

صفحة اللوحة نفسها: `GET /admin-panel` و`/admin-panel/styles` و`/script` و`/logo` و`/font/:weight`، كلها عامة (الملفات بس، والبيانات محتاجة دخول admin).

## نتيجة المقارنة
- كل مسار بيطلبه التطبيق أو اللوحة موجود في الخادم. **مفيش طلب على مسار مش موجود.**
- مسارات موجودة ومحدش بيستخدمها: `PATCH /users/me`، و`POST /users/me/change-password`، و`GET /wallet/limits`، و`POST /orders/quote`، و`POST /orders` (للنسخ القديمة).
