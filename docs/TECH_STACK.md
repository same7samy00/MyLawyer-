# التقنيات

**آخر تحقق:** 2026-11-07، من `pubspec.yaml` و`backend/package.json` والسيرفرات. ممنوع أي مكتبة جديدة من غير موافقة صاحب المشروع.

| الجزء | التقنية | النسخة |
|---|---|---|
| التطبيق | Flutter / Dart | 3.24.3 / 3.5.3 |
| الخادم | Node.js، وFastify، وTypeScript | 20.20، و5، و5.8 |
| قاعدة البيانات | PostgreSQL، ومن الخادم `pg` | 16 |
| اختبارات الخادم | `node --test` وPGlite | |
| لوحة التحكم والموقع | HTML وCSS وJS من غير مكتبات | |
| الخرايط | tileserver-gl وخريطة PMTiles لمصر، وOSRM للطرق، و`flutter_map` في التطبيق | |
| الإشعارات | Firebase Cloud Messaging | |
| الإيميل | Postfix وOpenDKIM على السيرفر، و`nodemailer` | |
| السيرفرات | Contabo، وUbuntu 24.04، وNginx 1.24، وLet's Encrypt | |
| الرفع | GitHub Actions بـ runner على السيرفر الجديد | |

## مكتبات التطبيق المهمة
`geolocator` (الموقع)، و`flutter_map` و`cached_network_image` (الخريطة والصور)، و`http`، و`shared_preferences` (المحفوظ العادي)، و`flutter_secure_storage` (المحفوظ السري)، و`firebase_messaging` و`flutter_local_notifications`، و`workmanager`، و`local_auth` (البصمة)، و`image_picker`، و`pdf` و`printing` (الفواتير)، و`webview_flutter`، و`url_launcher`.

## مكتبات الخادم
`fastify` و`@fastify/{cors,helmet,jwt,multipart,rate-limit}`، و`argon2`، و`pg`، و`zod`، و`nodemailer`، و`dotenv`.
