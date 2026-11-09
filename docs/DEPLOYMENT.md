# الرفع على الإنتاج

**آخر تحقق:** 2026-11-07. **القاعدة:** مفيش رفع غير لما صاحب المشروع يقول «ارفع» على الشغل ده بالذات (`AGENTS.md` القسم 7).

## 1. الخادم واللوحة والموقع (تلقائي)
1. الشغل على فرع `claude/...` أو `gemini/...`، والفحوصات كلها ناجحة (`docs/TESTING.md`).
2. قبل الرفع: `git tag checkpoint/before-<اسم>` على النسخة الشغالة دلوقتي، وراجع إن مفيش أسرار في الفرق.
3. `git push origin <الفرع>:main`. أي تغيير في `backend/**` بيشغّل `.github/workflows/deploy.yml`.
4. الـ workflow بيشتغل على runner السيرفر الجديد (`vps-mylawyer-api`): `npm ci` و`tsc` و`npm test`، وبعدين `backend/deploy.sh`.
5. `deploy.sh` بالترتيب:
   - نسخة من القاعدة في `/root/mylawyer-backups/mylawyer-<وقت>.sql.gz`، ويوقف لو النسخة فاضية.
   - نسخة من الكود الحالي.
   - بناء النسخة الجديدة على جنب، ونقلها، وتبديل الـ workers واحد واحد.
   - لو النسخة الجديدة ما ردّتش «UP» كذا مرة، بيرجّع القديمة لوحده.
   - ينسخ `public/site` لفولدر الموقع (بيضيف ويعدّل بس، ما بيمسحش ملفات اتشالت من الريبو: امسحها بإيدك).
   - الـ migrations بتشتغل لوحدها مع تشغيل الخادم (`src/database/migrate.ts`).
6. بعد الرفع: `curl https://my-lawyer.online/api/v1/health` لازم يرجع `release` بنفس رقم الـ commit.

## 2. التطبيق
بيتبني ويتنشر يدوي (`docs/DEVELOPMENT_GUIDE.md`). مفيش نشر تلقائي للمتاجر. عنوان الخادم في التطبيق `https://my-lawyer.online/api/v1`.

## 3. الخريطة
مفيش سيرفر خرايط بتاعنا. الخريطة من TomTom عن طريق خزنة Nginx على سيرفر التطبيق (`docs/GPS_SYSTEM.md`)، ومفيش حاجة تترفع. سيرفر الخرايط القديم اتمسح منه كل حاجة تخص الخريطة (2026-11-09)، وفاضل عليه التنبيهات بس.

## 4. الرجوع
- **كود:** `git revert <commit>` ورفع تاني، أو `git push origin checkpoint/<اسم>:main` بموافقة. وعلى السيرفر النسخة اللي قبلها في `/var/www/mylawyer/backend/.previous`.
- **قاعدة البيانات:** `docs/BACKUP_AND_RECOVERY.md`. الـ migrations ما بترجعش لوحدها.
