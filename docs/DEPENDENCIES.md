# المكتبات والخدمات

**آخر تحقق:** 2026-11-11. المرجع للإصدارات `pubspec.yaml` و`backend/package.json`. **مفيش مكتبة جديدة من غير موافقة صاحب المشروع** (`WORK_RULES.md`).

## 1. التطبيق (Flutter 3.24.3، Dart 3.5.3)
كل مكتبة اتأكدت إنها مستخدمة فعلًا في `lib/`.
| المكتبة | بتعمل إيه | فين |
|---|---|---|
| `http` | كل طلبات الخادم | `core/services/api_service.dart` |
| `flutter_secure_storage` | حفظ الجلسة وبيانات البصمة في خزنة الموبايل المشفرة | `api_service.dart` و`biometric_service.dart` |
| `shared_preferences` | المحفوظ عشان الشاشات تظهر فورًا | `core/services/saved_data.dart` والـ repositories |
| `flutter_map` و`latlong2` | الخريطة | `core/widgets/app_map_layer.dart` |
| `geolocator` | مكان الموبايل وأذوناته | `core/services/location_service.dart` و`device_permission_service.dart` |
| `workmanager` | تحديث مكان المحامي والتطبيق في الخلفية | `background_location_service.dart` |
| `firebase_core` و`firebase_messaging` | إشعارات الموبايل | `core/services/push_service.dart` |
| `flutter_local_notifications` | الإشعار الثابت وصوت التنبيه | `push_service.dart` |
| `cached_network_image` | صور المحامين | `core/widgets/profile_photo.dart` |
| `path_provider` | خزنة صور الخريطة على الموبايل | `app_cached_tile_provider.dart` |
| `image_picker` | الصورة الشخصية، والكارنيه، وصور التذاكر والاستشارة | شاشات التسجيل والدعم |
| `local_auth` | الدخول بالبصمة | `core/services/biometric_service.dart` |
| `url_launcher` | فتح الخرايط الخارجية ورابط التحديث | `external_navigation.dart` |
| `webview_flutter` | صفحة ملف المحامي على جوجل | `lawyer_google_profile_screen.dart` |
| `video_player` | فيديو البداية | `features/auth/splash_screen.dart` |
| `pdf` و`printing` | فاتورة PDF | `core/services/invoice_pdf_service.dart` |
| `flutter_localizations` | العربي ومن اليمين للشمال | `main.dart` |

## 2. الخادم (Node 20.20، TypeScript 5.9)
| المكتبة | بتعمل إيه |
|---|---|
| `fastify` | الخادم نفسه |
| `@fastify/helmet` و`cors` و`rate-limit` و`jwt` و`multipart` | رؤوس الأمان، وCORS، وحدود الطلبات، والدخول، ورفع الملفات |
| `pg` | PostgreSQL |
| `ioredis` و`bullmq` | Redis، وطابور الإشعارات والإيميلات |
| `argon2` | كلمات السر |
| `zod` | فحص المدخلات |
| `nodemailer` | الإيميل |
| `dotenv` | قراية `.env` |
| للتطوير بس: `tsx`، `typescript`، `@electric-sql/pglite` (قاعدة الاختبارات)، `@fastify/swagger` | |

إشعارات Firebase بتتبعت بطلبات HTTP مباشرة من `services/pushService.ts`، من غير مكتبة.

## 3. لوحة التحكم والموقع
JavaScript وCSS من غير أي مكتبة ولا خطوة بناء. الخط IBM Plex Sans Arabic محفوظ مع اللوحة.

## 4. الخدمات الخارجية
| الخدمة | لازمتها | لو وقعت |
|---|---|---|
| TomTom | صور الخريطة، ووقت الطريق، واسم المكان | المحفوظ بيفضل شغال، والجديد بيرجع 503 |
| OpenStreetMap | صور خريطة احتياطية لو خزنة سيرفرنا ما ردّتش (`MapConfig.fallbackTileUrl`)، ومش بتتحفظ | الخريطة تفضل على المحفوظ بس |
| Firebase Cloud Messaging | إشعارات الموبايل | الإشعار بيفضل جوه التطبيق، والطابور بيعيد 5 مرات |
| Cloudflare | DNS، وحماية، وكاش قدام السيرفر | الموقع والتطبيق يقفوا لحد ما يرجع |
| Let's Encrypt | شهادة https على السيرفر | الشهادة الحالية شغالة لحد تاريخها |
| GitHub Actions | الرفع التلقائي | الرفع يقف، والشغال يفضل شغال |
| Contabo | السيرفرين | `BACKUP_AND_RECOVERY.md` |

**مفيش:** بوابة دفع (الدفع تجريبي)، ولا خدمة SMS (الأكواد بالإيميل)، ولا Analytics، ولا Docker.

## 5. الإصدارات
- `npm audit`: صفر ثغرات (2026-11-11).
- فيه إصدارات أحدث لمكتبات كتير في الخادم والتطبيق، و**ما اتحدثتش عن قصد**: كله شغال ومتجرب، والتحديث من غير سبب مخاطرة. التحديث يبقى لسبب (ثغرة، أو شرط من المتجر) وباختبار كامل.
- Flutter 3.24.3 صدر في سبتمبر 2024. راجع `KNOWN_ISSUES.md` (شرط جوجل لمستوى الـ API).
