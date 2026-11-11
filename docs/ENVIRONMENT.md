# البيئات والإعدادات

**آخر تحقق:** 2026-11-11، من الكود ومن أسماء المتغيرات على السيرفرين (من غير قيم). الملف ده فيه **الأسماء والأماكن بس**، وممنوع أي قيمة سرية هنا. القالب في `backend/.env.example`.

## 1. البيئات
| البيئة | فين | القاعدة |
|---|---|---|
| الإنتاج | السيرفرين (`SERVER_ARCHITECTURE.md`) | `mylawyer_prod` الحقيقية. **مفيش بيئة تجريبية (staging)** |
| جهاز المطور | `backend/` محليًا (`npm run dev`) | قاعدة محلية `mylawyer_dev`، أو معاينة اللوحة بقاعدة في الذاكرة (`npm run preview:panel`) |
| الاختبارات | `npm test` و`flutter test` | قاعدة جوه الذاكرة (PGlite) للخادم، وخادم وهمي للتطبيق. ما بيكلموش الإنتاج |

## 2. التطبيق
| الإعداد | فين | ملاحظة |
|---|---|---|
| عنوان الخادم | `lib/core/config/app_config.dart` | نسخة Release مقيدة بـ `https://my-lawyer.online/api/v1` مهما كانت قيم البناء |
| خادم تاني للتجربة | `--dart-define=APP_ENV=development --dart-define=API_BASE_URL=http://...` | في Debug بس |
| رقم النسخة | `version` في `pubspec.yaml`، و`AppConfig.build` | لازم يبقوا واحد (اختبار `test/app_build_test.dart`). الخادم بيقارنه بأقل نسخة مسموحة |
| الخريطة | `lib/core/constants/map_config.dart` | الصور من خزنة سيرفرنا. مفيش مفتاح خرايط في التطبيق |
| Firebase | `android/app/google-services.json` (بره Git) | إشعارات الموبايل |
| التوقيع | `android/key.properties` و`android/mylawyer-release.jks` (بره Git) | من غيرهم البناء بيوقّع بمفتاح التجربة |

## 3. الخادم: متغيرات `.env`
«على السيرفر» = الاسم موجود فعلًا في `.env` على السيرفر ده يوم 2026-11-11.
| المتغير | لازمته | الأساسي | التاني |
|---|---|:---:|:---:|
| `NODE_ENV` | `production` بيشغّل فحص الأسرار وكود دخول اللوحة | ✅ | ✅ |
| `PORT` و`HOST` | `4000`. الأساسي `127.0.0.1` ورا Nginx، والتاني مفتوح للخط الخاص بس | ✅ | ✅ |
| `DATABASE_URL` | القاعدة الأساسية. الإنتاج ما بيشتغلش من غيره | ✅ | ✅ (من الخط الخاص) |
| `DATABASE_READ_URL` | نسخة القراية، للخريطة والقوايم والتقييمات. فاضي = القاعدة الأساسية | — | ✅ |
| `REDIS_URL` | الذاكرة السريعة والطابور. فاضي = كل عملية بتعد لوحدها | ✅ | ✅ |
| `JWT_SECRET` | سر توقيع الدخول، 32 حرف على الأقل. الإنتاج ما بيشتغلش من غيره | ✅ | ✅ (لازم نفس القيمة عشان الدخول يشتغل على السيرفرين) |
| `PUBLIC_STORAGE_PATH` و`PRIVATE_STORAGE_PATH` | مخزن الصور العامة، والمخزن الخاص | ✅ | ✅ |
| `SMTP_HOST` و`SMTP_PORT` و`SMTP_SECURE` و`EMAIL_FROM` | الإيميل من Postfix المحلي | ✅ | ✅ |
| `ADMIN_CODE_EMAIL` | الإيميل اللي بيوصله كود دخول اللوحة | ✅ | ✅ |
| `TOMTOM_ROUTING_KEY` | مفتاح الطرق واسم المكان | ✅ | ✅ |
| `CORS_ORIGIN` | `*` (الدخول بتوكن مش بكوكي) | ✅ | ✅ |
| `TRUST_PROXY` | مين موثوق يبعت عنوان الزائر الحقيقي. الافتراضي `loopback` | — | ✅ |
| `JOB_WORKER` | `off` على التاني: بيحط في الطابور وما بيشغّلوش، عشان الإيميل الموقّع يطلع من الأساسي بس | — | ✅ |
| `JWT_REFRESH_SECRET` | **الكود ما بيقراهوش.** متساب من نظام قديم (`KNOWN_ISSUES.md`) | ✅ | ✅ |

**متغيرات ليها قيمة افتراضية ومش مكتوبة على السيرفر:** `SMTP_USER` و`SMTP_PASS`، و`ADMIN_LOGIN_CODE` (`on` أو `off`)، و`FIREBASE_SERVICE_ACCOUNT_PATH`، و`REQUEST_ROAD_CANDIDATES` (20)، و`PASSWORD_SLOTS` (2)، و`DB_READ_POOL_MAX` (5)، و`ALLOW_MOCK_LOCATION` (ممنوع في الإنتاج بعد الإطلاق)، و`WALLET_TRANSFERS` (فاضي = التحويل بين الحسابات مقفول، و`on` يرجّعه. في التطبيق الزرار بيرجع بـ `--dart-define=WALLET_TRANSFERS=true` في البناء).

**في إعداد الخدمة مش في `.env`** (`systemctl cat mylawyer-backend`): `WEB_WORKERS` (5 على الأساسي و3 على التاني)، و`DB_POOL_MAX` (15)، وحد الذاكرة 8 جيجا.

**الخادم بيحطه لنفسه:** `MYLAWYER_RELEASE` (رقم الـ commit، وبيظهر في `/health`).

## 4. إعدادات بره الخادم
| الإعداد | فين |
|---|---|
| Nginx (التوزيع، والخزنتين، والحدود، ورؤوس الأمان) | `/etc/nginx/sites-available/mylawyer` و`/etc/nginx/conf.d/` على الأساسي، ونسخة على التاني كل دقيقة |
| عناوين Cloudflare الموثوقة | `/etc/nginx/conf.d/cloudflare-real-ip.conf`، وقواعد UFW باسم `Cloudflare` |
| قاعدة البيانات | `/etc/postgresql/16/main/conf.d/` |
| Redis | `/etc/redis/mylawyer.conf` |
| المهام المجدولة | `/etc/cron.d/mylawyer-backup` و`mylawyer-watch` و`mylawyer-pgbackrest`، و`mylawyer-second-sync.timer` |
| السيرفر التاني للرفع | `/etc/mylawyer/second-server` على الأساسي |

**ملفات إعداد السيرفر دي مش في Git**: موجودة على السيرفرين بس (`KNOWN_ISSUES.md`).
