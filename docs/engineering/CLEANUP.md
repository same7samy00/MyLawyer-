# التنضيف وإعادة التنظيم

**آخر تحقق:** 2026-11-06. **الغرض:** إيه اللي اتشال بدليل، وإيه اللي اتساب ليه، وخطة إعادة التنظيم بالترتيب. أي نموذج يكمل من أول خطوة حالتها «لسه».

## 1. طريقة الحصر (عشان ما تتعادش)
- **ملفات Dart:** كل ملف في `lib` اسمه متدور عليه في كل `import` في `lib` و`test`. **النتيجة:** مفيش ملف مش مستخدم.
- **classes ودوال `static`:** أي اسم بيظهر مرة واحدة بس في `lib` و`test`. **النتيجة:** مفيش.
- **مكتبات `pubspec.yaml`:** أي مكتبة من غير `package:<الاسم>/` في `lib` و`test`. **النتيجة:** `lottie` بس.
- **الصور والخطوط:** اسم كل ملف في `assets` متدور عليه في `lib` و`pubspec.yaml` و`android` و`ios`، ومعاه أوزان `FontWeight` المستخدمة فعلًا.
- **الخادم:** كل `export` في `backend/src` متدور على استخدامه. **النتيجة:** مفيش دالة ميتة، وفيه 16 اسم متصدّر ومستخدم في ملفه بس، وده مش ضار.
- **لوحة التحكم:** كل ملف في `public/admin/js` و`css` و`fonts` موجود في قوايم `admin/panel.ts`.
- **المسارات:** مقارنة الخادم بالتطبيق واللوحة (`API_REFERENCE.md`).

## 2. سجل الحذف
| اللي اتشال | التصنيف | الدليل | الأثر |
|---|---|---|---|
| مكتبة `lottie` | CONFIRMED UNUSED | مفيش `package:lottie` في `lib` ولا `test`. كانت لرسمة شاشة الخريطة القديمة (`CHANGELOG_ARCHIVE.md`) | مكتبة أقل |
| `assets/images/splash_gif.json` (27 كيلوبايت) | CONFIRMED UNUSED | مفيش ذكر ليه في `lib` ولا `android` ولا `ios`، غير في الأرشيف | حجم أقل |
| `IBMPlexSansArabic-Thin/ExtraLight/Light.ttf` (690 كيلوبايت) | CONFIRMED UNUSED | مفيش `FontWeight.w100/w200/w300/light/thin` في `lib`، والوزن الافتراضي 400، والفاتورة PDF بتحمّل Regular وSemiBold بس | التطبيق أصغر 690 كيلوبايت تقريبًا، ومفيش تغيير في الشكل |

## 3. اتساب عن قصد
| العنصر | التصنيف | السبب |
|---|---|---|
| `POST /orders` و`POST /orders/quote` و`resolveClientQuote` وجدول `client_problem_prices` | DEPRECATED، مطلوب | النسخ القديمة من التطبيق لسه بتستخدمها. تتشال بعد ما كل الأجهزة تتحدث (قرار في `HANDOFF.md`) |
| `POST /orders/:id/accept` و`/reject` | REQUIRED | التطبيق بيستخدمهم مع طلبات `PENDING` القديمة |
| `PATCH /users/me` و`POST /users/me/change-password` و`GET /wallet/limits` | POTENTIALLY UNUSED | التطبيق ما بيستخدمهمش دلوقتي، لكن تغيير كلمة المرور ممكن يتضاف كشاشة. محتاج قرار |
| أعمدة `completion_code` و`degree` و`specialty` | POTENTIALLY UNUSED | بيانات قديمة في الإنتاج. ممنوع نشيل عمود من غير موافقة ومن غير migration فيها طريقة رجوع |
| خطوط اللوحة `IBMPlexSansArabic-Thin...woff2` | REQUIRED | ملفات منفصلة للوحة، و`panel.ts` بيقدمها كلها |
| فرعي `master` و`map-test` المحليين | REQUIRED | `master` فيه التاريخ القديم (ممنوع يترفع أو يتمسح). و`map-test` مش معروف هو لمين، فمحدش يمسحه |

## 4. خطة إعادة التنظيم (بالترتيب، كل خطوة commit لوحدها بفحوصاتها)
| # | الخطوة | الخطورة | الحالة |
|---|---|---|---|
| 1 | `ProfileRepository` بدل 4 شاشات بتطلب `/users/me` بنفسها (CODE-01). الشاشات اللي بتفتح مع بعض بتستنى طلب واحد | قليلة | **اتعملت 2026-11-06** |
| 2 | شرط «المحامي عنده طلب مفتوح» مكتوب 5 مرات (`requests/service.ts` و`lifecycle/service.ts` و`lawyers/routes.ts` و`orders/create.ts` و`lifecycle/sweep.ts`). يتوحّد في دالة SQL واحدة | متوسطة، بيلمس توزيع الطلبات | لسه |
| 3 | تقسيم `auth/routes.ts` (600 سطر) لـ `register.ts` و`session.ts` و`password.ts`. نقل بس، من غير تغيير سلوك | قليلة | لسه |
| 4 | تقسيم `admin/directory.ts` (440 سطر) لـ `users.ts` و`orders.ts` و`discipline.ts` (الإنذارات والمخالفات والتجميد) | قليلة | لسه |
| 5 | `lib/core/services` فيه 17 ملف مخلوطين. خدمات البيانات (`order_store` و`saved_data` و`map_lawyer_loader` و`notification_center`) تتنقل لـ `lib/data`، وخدمات الجهاز (الموقع والأذونات والإشعارات) تفضل | متوسطة، imports كتير | لسه |
| 6 | `lib/core/widgets` فيه 34 ملف في مجلد واحد. يتقسموا (sheets، وcards، وbuttons، وmap) | قليلة، نقل بس | لسه |
| 7 | الشاشات اللي فوق 450 سطر (`auth_service.dart` و`email_verification_screen.dart` و`order_details_sheet.dart` و`client_register_steps.dart` و`login_screen.dart`) تتقسم لما حد يشتغل عليها | قليلة | لسه |
| 8 | عمليات الإدارة على الفلوس جوه معاملة واحدة (BUG-06) | فلوس | **محتاج موافقة** |
| 9 | شيل المسار القديم (`POST /orders`) بعد إجبار التحديث | محتاج قرار | **محتاج قرار** |

**ليه ما اتعملتش الخطوات كلها مرة واحدة:** التوجيه نفسه بيقول «مفيش refactor كبير مرة واحدة». الخطوات 2 لـ 7 بتلمس عشرات الملفات، وكل واحدة محتاجة الفحوصات كاملة لوحدها. والخطوتين 8 و9 محتاجين موافقة صاحب المشروع.

## 5. الفحوصات بعد التنضيف (2026-11-06)
- `flutter analyze`: `No issues found!`. `flutter test`: 128 نجحوا و3 متخطين، بعد كل خطوة (الـ Repository، والمكتبة، والخطوط).
- `flutter build apk` ما اتشغلش، فحجم التطبيق بعد الحذف ما اتقاسش.
