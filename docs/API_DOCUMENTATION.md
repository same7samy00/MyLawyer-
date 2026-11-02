# 🏛️ توثيق واجهات برمجة التطبيقات (MyLawyer Production API Reference)

> **الإصدار:** 1.0.0  
> **البيئة الإنتاجية:** `https://my-lawyer.online/api/v1`  
> **مستندات التفاعل الحي (Swagger / OpenAPI):** `https://my-lawyer.online/docs`

---

## 📌 1. المعايير الهندسية الموحدة (API Standards)

1. **نمط الرد الموحد (Unified JSON Response Schema):**
   ```json
   {
     "success": true,
     "message": "نص توضيحي للعملية (اختياري)",
     "data": {},
     "error": "رسالة الخطأ عند الفشل (null في حالة النجاح)"
   }
   ```
2. **المصادقة والتفويض (Authentication & Authorization):**
   - تمرير الـ Access Token في الترويسة:  
     `Authorization: Bearer <JWT_ACCESS_TOKEN>`
   - الصلاحيات مقسمة حسب الأدوار: `client`، `lawyer`، `admin`.
3. **أكواد الحالة القياسية (HTTP Status Codes):**
   - `200 OK`: نجاح العملية مع إرجاع بيانات.
   - `201 Created`: نجاح إنشاء مورد جديد (طلب، مستخدم، توكن).
   - `400 Bad Request`: خطأ في المدخلات والتحقق.
   - `401 Unauthorized`: غياب أو انتهاء صلاحية التوكن.
   - `403 Forbidden`: محاولة الوصول لمورد غير مصرح للمستخدم به.
   - `404 Not Found`: العنصر أو المسار غير موجود.
   - `409 Conflict`: تعارض (مثل قبول طلب تم قبوله مسبقاً، أو رقم هاتف مكرر).
   - `500 Internal Server Error`: خطأ غير متوقع في الخادم.

---

## 🚀 2. خريطة المسارات المعتمدة (Endpoint Registry)

### 🏥 أ. فحص صحة النظام (Health & System Diagnostics)
| المسار | الطريقة | الصلاحية | الوظيفة |
| :--- | :---: | :---: | :--- |
| `/health` | `GET` | عام (Public) | فحص سلامة السيرفر وقاعدة بيانات PostgreSQL وهجرة الجداول |

---

### 🔐 ب. المصادقة والحسابات (Authentication & Accounts)
| المسار | الطريقة | الصلاحية | الوظيفة |
| :--- | :---: | :---: | :--- |
| `/auth/register` | `POST` | عام | تسجيل حساب جديد لموكل أو محامٍ (تفعيل فوري للمحامي) |
| `/auth/verify-otp` | `POST` | عام | التحقق من كود البريد الإلكتروني وتفعيل الحساب |
| `/auth/resend-otp` | `POST` | عام | إعادة إرسال كود التحقق |
| `/auth/login` | `POST` | عام | تسجيل الدخول بالهاتف وكلمة المرور والحصول على JWT |
| `/auth/refresh` | `POST` | عام | تجديد الـ Access Token عبر الـ Refresh Token مع تدوير الـ Refresh Token |
| `/auth/logout` | `POST` | عام | إنهاء الجلسة وإلغاء الـ Refresh Token |
| `/auth/forgot-password` | `POST` | عام | طلب رمز استعادة كلمة المرور على البريد |
| `/auth/reset-password` | `POST` | عام | تعيين كلمة مرور جديدة بالرمز وإلغاء كل الجلسات |
| `/users/me` | `GET` | مصرح | بيانات الحساب الحالي، ويعتمد عليها فحص الجلسة عند فتح التطبيق |

---

### 👨‍⚖️ ج. خدمات المحامين والبحث الجغرافي (Lawyers & Geo Queries)
| المسار | الطريقة | الصلاحية | الوظيفة |
| :--- | :---: | :---: | :--- |
| `/lawyers/nearby` | `GET` | عام | استعلام المحامين الأقرب في النطاق الجغرافي المتاحين فعلياً |
| `/lawyers/profile` | `GET` | محامٍ | جلب بيانات الملف الشخصي للمحامي المسجل حالياً |
| `/lawyers/profile` | `PUT` | محامٍ | تحديث بيانات الملف الشخصي للمحامي |
| `/lawyers/me/location` | `POST` | محامٍ | تحديث الموقع الجغرافي اللحظي وحالة التوفر للمحامي |
| `/lawyers/avatar` | `POST` | محامٍ | رفع الصورة الشخصية للمحامي |
| `/lawyers/documents` | `POST` | محامٍ | رفع مستندات القيد والكارنيه |

---

### ⚡ د. خدمة «محاميك حالاً» والطلبات (Urgent Legal Orders)
| المسار | الطريقة | الصلاحية | الوظيفة |
| :--- | :---: | :---: | :--- |
| `/orders` | `POST` | موكل | إنشاء طلب استشارة/تمثيل عاجل جديد وربطه بالمحامي |
| `/orders` | `GET` | مصرح | استرجاع قائمة طلبات المستخدم (موكل أو محامٍ) |
| `/orders/:id` | `GET` | أطراف الطلب | جلب التفاصيل الكاملة للطلب والحالة اللحظية (Polling) |
| `/orders/:id/accept` | `POST` | محامٍ | قبول الطلب من المحامي المستهدف (محمي من التكرار) |
| `/orders/:id/reject` | `POST` | محامٍ | اعتذار المحامي عن المهمة مع تسجيل السبب |
| `/orders/:id/confirm-payment` | `POST` | موكل | تأكيد السداد بعد موافقة المحامي وخلال 10 دقايق، و`{method: "wallet"}` للدفع من الرصيد |
| `/orders/:id/complete` | `POST` | المحامي | إنهاء المهمة بكود الموكل `{code}` فقط، بعد الدفع وتسجيل الوصول، وإلا يرجع `409` |
| `/orders/:id/complaint` | `POST` | الموكل | تقديم شكوى `{reason}` أثناء المهمة أو بعدها |
| `/orders/:id/review` | `POST`/`PUT` | الموكل | تقييم خلال 7 أيام، وتعديل واحد قبل النشر |
| `/orders/:id/appeal` | `POST` | المحامي | اعتراض `{reason}` خلال 7 أيام من انتهاء المهلة |
| `/orders/quote` | `POST` | موكل | السعر قبل إرسال الطلب `{problemType}` |
| `/orders/:id/arrive` | `POST` | المحامي | تسجيل الوصول `{latitude, longitude}` في نطاق 500 متر من الموكل |
| `/orders/:id/withdraw` | `POST` | المحامي | الاعتذار بعد الدفع، والمبلغ يرجع للموكل وتُسجل نقطة |
| `/orders/:id/report` | `POST` | المحامي | بلاغ `{reason}` عن مشكلة مع الموكل |
| `/orders/wallet/me` | `GET` | مصرح | أرصدة المحامي، أو رصيد الموكل المرتجع |
| `/lawyers/:id/reviews` | `GET` | عام | التقييمات المنشورة |
| `/lawyers/me/reviews/:reviewId/report` | `POST` | المحامي | الإبلاغ عن تعليق |
| `/notifications` | `GET` | مصرح | آخر الإشعارات |
| `/notifications/summary` | `GET` | مصرح | عداد غير المقروء والطلبات |
| `/notifications/read-all` | `POST` | مصرح | تعليم الكل كمقروء |
| `/admin/complaints`، `/admin/complaints/:id/resolve` | `GET`/`POST` | الإدارة | مراجعة الشكاوى والفصل فيها |
| `/admin/appeals`، `/admin/appeals/:id/resolve` | `GET`/`POST` | الإدارة | مراجعة الاعتراضات |
| `/notifications/device-token` | `POST` | مصرح | تسجيل جهاز المستخدم لإشعارات الموبايل، و`/remove` لإلغائه |
| `/admin/prices` | `GET`/`PUT` | الإدارة | نطاق السعر ونسبة المنصة لكل مشكلة، والحفظ يلغي الأسعار المحفوظة للموكلين في نفس المشكلة |
| `/admin/commission` | `POST` | الإدارة | نسبة واحدة لكل الخدمات، للطلبات الجديدة فقط |
| `/admin/tickets` | `GET` | الإدارة | كل ما ينتظر قرار، والأقدم أولاً |
| `/admin/orders/:id/unlock-code` | `POST` | الإدارة | فتح كود مقفول بعد 5 محاولات خاطئة |
| `/admin/reports/:id/resolve` | `POST` | الإدارة | إغلاق بلاغ محامي |
| `/admin/overview` | `GET` | إدارة | أرقام عامة عن الحسابات والطلبات |
| `/admin/users?role=&q=` | `GET` | إدارة | قائمة المحامين أو الموكلين والبحث فيهم |
| `/admin/users/:id` | `GET` | إدارة | بروفايل كامل بالطلبات والتقييمات والشكاوى |
| `/admin/users/:id/status` | `POST` | إدارة | إيقاف الحساب أو تفعيله |
| `/admin/orders?q=&status=` | `GET` | إدارة | البحث في الطلبات |
| `/admin/orders/:id` | `GET` | إدارة | الطلب ودورة حياته كاملة |
| `/admin/reviews` | `GET` | إدارة | كل التقييمات |
| `/admin-panel` | `GET` | عام | صفحة لوحة التحكم، وبياناتها تتطلب حساب إدارة |
| `/admin/reviews/reported`، `/admin/reviews/:id/moderate` | `GET`/`POST` | الإدارة | مراجعة التعليقات |
| `/orders/:id/cancel` | `POST` | أطراف الطلب | إلغاء قبل الدفع، وللموكل بعد الدفع قبل وصول المحامي مع رد المبلغ لرصيده |

---

### 🛡️ هـ. إدارة النظام ومراجعة الاعتماد (Admin Management)
| المسار | الطريقة | الصلاحية | الوظيفة |
| :--- | :---: | :---: | :--- |
| `/admin/lawyers/pending` | `GET` | مسؤول (Admin) | استعراض المحامين قيد المراجعة |
| `/admin/lawyers/:id/approve` | `POST` | مسؤول (Admin) | اعتماد وترقية حساب المحامي يدوياً |
| `/admin/lawyers/:id/reject` | `POST` | مسؤول (Admin) | رفض اعتماد المحامي مع تدوين السبب |

