# ⚡ Development & Maintenance Guide - My Lawyer

## 1. نظرة عامة (Overview)
يهدف هذا الدليل إلى توفير إرشادات عملية دقيقة للمطورين ونماذج الذكاء الاصطناعي لتطوير وصيانة تطبيق **My Lawyer** بسرعة واحترافية، بالاعتماد على ميزة **Hot Reload** دون الحاجة لإعادة التجميع الكامل المتكرر عبر Gradle.

---

## 2. التشغيل على الهاتف الحقيقي عبر ADB (ADB Device Workflow)

### أ. فحص اتصال الهاتف
تأكد من تفعيل وضع المطورين وتصحيح أخطاء USB (USB Debugging) على الهاتف، ثم نفذ:
```powershell
& "C:\src\flutter\bin\flutter.bat" devices
```
سيظهر الهاتف المتصل (مثال: `RMX3997` بمعرف `OFDI4TCAFA9XBQOJ`).

### ب. تشغيل التطبيق في نمط التطوير
```powershell
Set-Location "D:\KAREM"
& "C:\src\flutter\bin\flutter.bat" run -d OFDI4TCAFA9XBQOJ
```

### ج. مفاتيح التحكم السريع (Hot Reload / Hot Restart)
أثناء تشغيل جلسة Flutter في التيرمينال:
- **`r` (Hot Reload):** تحديث الشاشات والتصميم والخطوط والألوان في أقل من ثانية واحدة، مع الحفاظ الكامل على حالة التطبيق والجلسة.
- **`R` (Hot Restart):** إعادة تشغيل التطبيق من نقطة البداية `main()` وإعادة تهيئة الـ State في ثانية أو ثانيتين.
- **`p`:** إظهار خطوط التصميم والشبكة (Debug Paint Grid).
- **`q`:** إنهاء الجلسة وإغلاق التطبيق.

---

## 3. بوابات الجودة الإلزامية (Verification Quality Gates)

قبل تقديم أي تعديل أو الانتقال للخطوة التالية، يجب تشغيل الأمرين التاليين والتأكد من نجاحهما:

### 1. التحليل البرمجي الصارم (Static Analysis)
```powershell
& "C:\src\flutter\bin\flutter.bat" analyze
```
**المعيار المطلوب:** `No issues found!` بدون أي أخطاء أو تحذيرات.

### 2. الاختبارات المؤتمتة (Automated Tests)
```powershell
& "C:\src\flutter\bin\flutter.bat" test
```
**المعيار المطلوب:** `All tests passed!`.

---

## 4. منهجية حفظ واستقرار الكود (Git Discipline)

1. **نقاط الحفظ الواضحة (Clear Commits):**
   - تنفيذ `git commit` برسائل معبرة بعد كل مرحلة أو مهمة ناجحة وموثقة.
2. **عدم رفع الأسرار أو الملفات المؤقتة:**
   - ملف `.gitignore` يقوم بتجاهل `.dart_tool/` و `build/` وملفات البيئة الحساسة.
3. **التراجع الآمن:**
   - عند مواجهة خطأ معماري غير متوقع، استخدم التراجع الآمن إلى آخر نقطة حفظ مستقرة.

---

## 5. الخطوات الست لتنفيذ أي مهمة قادمة (The 6-Step Cycle)

1. **الفهم (Understand):** قراءة ميثاق المشروع (`AGENTS.md`) وفحص الكود القائم بدقة.
2. **التخطيط (Plan):** تحديد التعديل الأدنى والأكثر كفاءة دون مساس بالوظائف السليمة.
3. **التنفيذ (Execute):** كتابة كود نظيف ملتزم بالثيم (الحواف المعتمدة والألوان الرسمية).
4. **التحقق (Verify):** تشغيل `flutter analyze` و `flutter test`.
5. **التوثيق (Document):** تحديث `CHANGELOG.md` وكافة ملفات التوثيق المعنية فورياً.
6. **التسليم (Deliver):** تقديم ملخص مكتمل ومفصل لما تم إنجازه.

---

## البيئات والاختبارات

- التشغيل الافتراضي يستخدم خادم الإنتاج. لاستخدام خادم تطوير:
  `flutter run --dart-define=APP_ENV=development --dart-define=API_BASE_URL=http://HOST/api/v1`
- إصدار Release يتجاهل هذه القيم ويبقى مقيداً بخادم الإنتاج.
- `flutter test` يعمل بالكامل على خادم وهمي محلي (`test/helpers/fake_backend.dart`) ولا يتصل بالإنتاج.
- اختبارات الاتصال بالخادم الحي اختيارية وللقراءة فقط:
  `flutter test test/api_integration_test.dart --dart-define=RUN_LIVE_API_TESTS=true`

---

## تجربة العميل والمحامي على موبايل واحد

هذا الأمر يبني نسخة ثانية باسم «My Lawyer محامي» تُثبت بجوار النسخة الأصلية، ولكل نسخة تسجيل دخول مستقل:

```bash
flutter build apk --release -PlawyerTestApp=true
```

## متابعة العمل

الوضع الحالي والمهام التالية وأوامر البناء في [`HANDOFF.md`](./HANDOFF.md).

## رفع الخادم

الطريقة الأساسية: `git push origin main`. لو التعديل في `backend`، يشغل `.github/workflows/deploy.yml` الفحوص ثم `backend/deploy.sh` على الـrunner الموجود في الخادم في `/actions-runner-mylawyer`. طلبات الـpull request لا تشغله لأن الـrunner له صلاحية root.

الطريقة اليدوية:

يتم الرفع من جهاز المطور بعد عمل commit، بالمفتاح اللي في `.access/` (`docs/ACCESS.md`).

**خطوات `backend/deploy.sh` (من 2026-11-06):**
1. نسخة احتياطية من قاعدة البيانات والكود في `/root/mylawyer-backups`.
2. يبني النسخة الجديدة في مجلد مؤقت، ويسطّب مكتبات التشغيل بس، ويكتب رقم النسخة (الـ commit) في `dist/RELEASE`.
3. يبدّل `dist` و`migrations` و`public` و`package*.json` و`node_modules` في ثواني، والقديم يتحط في `.previous/`.
4. **من غير توقف:** لو `dist/server.js` ما اتغيرش، بيبعت `SIGHUP` للعملية الرئيسية. ساعتها بتشغّل الـ migrations الجديدة، وبتبدّل الـ workers واحد واحد: كل جديد لازم يبتدي يستقبل طلبات قبل ما القديم يقفل. ولو `server.js` اتغير، أو الخدمة واقفة، بيعمل `systemctl restart` (فيه توقف ثواني).
5. لازم `/api/v1/health` يرد `UP` بنفس رقم النسخة 6 مرات ورا بعض في خلال 90 ثانية. **لو ده ما حصلش، الكود القديم بيرجع لوحده** والخدمة بتتعاد. الـ migrations ما بترجعش، والنسخة الاحتياطية موجودة.
6. المهام الزمنية (`sweep`) بتشتغل في كل worker، بس قفل في قاعدة البيانات (`pg_try_advisory_lock`) بيخلي واحد بس يشتغل في المرة، فهي مش بتقف أثناء التبديل.

```bash
git archive HEAD backend | ssh -F D:/KAREM/.access/ssh_config mylawyer-vps 'cat > /tmp/mylawyer-backend.tar && tar -xOf /tmp/mylawyer-backend.tar backend/deploy.sh | tr -d "\r" | bash -s manual-$(date +%s)'
```

## لوحة التحكم
- الكود في `backend/public/admin/`، وتقسيمه في `docs/ARCHITECTURE.md` (4.1).
- المعاينة المحلية: `cd backend && npm run preview:panel`، ثم `http://127.0.0.1:3900/api/v1/admin-panel`.
- كل نصوص اللوحة عربية فصحى، وأي إجراء جديد يتضاف في زر «اتخاذ إجراء» بخطوات ومراجعة.
- أي قرار إداري جديد يتسجل بـ `logAdminAction`، وأي تغيير في حالة طلب أو أتعابه يتسجل في `order_status_logs`.

## العمل بين الحسابات
دورة البداية والتسليم في `AGENTS.md` القسم 7. الملفات المحلية خارج Git، زي `admin-credentials.txt`، ما تتنقلش لأي مستند.
