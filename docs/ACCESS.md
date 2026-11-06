# الوصول للريبو والسيرفر

**آخر تحقق:** 2026-11-06. الملف ده ما فيهوش ولا هيبقى فيه أي كلمة مرور أو مفتاح أو توكن.

## القاعدة الأساسية
- القراءة مسموحة.
- الكتابة على أي حاجة بره الجهاز بتحصل بس لما صاحب المشروع يقول «ارفع» على الشغل ده بالذات. ساعتها ارفع على طول، من غير ما تسأله عن أي توكن أو كلمة سر.
- **ممنوع أي نموذج يطلب من صاحب المشروع توكن أو بيانات سيرفر.** كل حاجة موجودة في `.access/`، ولو حاجة ناقصة اكتب إيه الناقص بالظبط.

التفاصيل في `AGENTS.md` القسم 7.

## مجلد `.access/` (جوه فولدر المشروع، وGit بيتجاهله)
| الملف | لازمته |
|---|---|
| `git-credentials` | توكن GitHub بصيغة `git credential store` |
| `mylawyer_deploy` و`mylawyer_deploy.pub` | مفتاح SSH للسيرفر، وصلاحيته لمستخدم Windows بس |
| `known_hosts_mylawyer` | بصمة السيرفر |
| `ssh_config` | الاسم المختصر `mylawyer-vps` بمسارات المجلد ده |
| `admin-credentials.txt` | دخول لوحة التحكم |
| `test-accounts.txt` | الحسابات التجريبية |

**من أي برنامج (Claude أو Gemini أو Cursor أو terminal):**
```bash
ssh -F D:/KAREM/.access/ssh_config mylawyer-vps
```
```bash
git -c credential.helper= -c "credential.helper=store --file=D:/KAREM/.access/git-credentials" push origin <الفرع>
```
وعلى جهاز صاحب المشروع نفسه، `ssh mylawyer-vps` و`git push` العادي بيشتغلوا كمان (Windows Credential Manager و`~/.ssh/config`).

**قبل أي commit:** شغّل `git status` واتأكد إن مفيش أي ملف من `.access/` ظاهر. لو `git check-ignore .access/git-credentials` ما طبعش حاجة، اقف فورًا لأن الريبو **عام**.
لو التوكن أو المفتاح اتغير، حدّث الملف اللي في `.access/` بس.

ملفات تانية سرية بره المجلد ومتجاهلة في Git، ولازم تفضل في مكانها لأن البناء بيقراها من هناك: `android/key.properties` و`android/mylawyer-release.jks` و`android/app/google-services.json` و`backend/firebase-service-account.json`.

| العملية | الحكم |
|---|---|
| تعديل الملفات محليًا، والاختبارات، والبناء | مسموح |
| commit محلي على فرع `claude/...` أو `gemini/...` | مسموح |
| `git fetch` و`git log origin/...` وقراءة GitHub | مسموح |
| `git push` لأي فرع، أو Pull Request، أو tag | **لما صاحب المشروع يقول «ارفع»** |
| قراءة ملفات السيرفر والسجلات وحالة الخدمات | مسموح |
| أي تعديل على السيرفر، أو إعادة تشغيل، أو migration، أو رفع | **موافقة صريحة كل مرة** |
| مسح أو تعديل بيانات الإنتاج | **موافقة صريحة كل مرة** |

## الريبو
- **المكان:** GitHub، الريبو `same7samy00/MyLawyer-`، والريموت اسمه `origin` (HTTPS).
- **الدخول:** توكن محفوظ في Windows Credential Manager (`credential.helper=manager`، والمستخدم `x-access-token`). يعني `git push` بيشتغل من غير ما حد يكتب حاجة، **وعشان كده لازم الموافقة قبله**.
- **الفروع:** `main` هو الإنتاج. الفرع المحلي `master` فيه التاريخ القديم اللي فيه أسرار، وممنوع يترفع أبدًا.
- **الرفع التلقائي:** `.github/workflows/deploy.yml` بيشتغل مع أي push على `main` يغيّر `backend/**`، على runner موجود على السيرفر نفسه. بيشغل `tsc` و`npm test` وبعدين `backend/deploy.sh`. يعني **push على `main` = رفع على الإنتاج**.

## السيرفر
- **الاسم المختصر:** `ssh mylawyer-vps` (الإعداد في `~/.ssh/config` على جهاز صاحب المشروع، بالمفتاح `~/.ssh/mylawyer_deploy`).
- **الدور:** إنتاج بس، ومفيش سيرفر تجريبي.
- **النظام:** Ubuntu 24.04، والخدمات: `mylawyer-backend` (systemd، على `127.0.0.1:4000`)، وPostgreSQL 16 (محلي)، وNginx 1.24، وDocker للخرائط (`mylawyer-osrm` و`mylawyer-tileserver`، محليين)، وPostfix وOpenDKIM.
- **المسارات:** التطبيق في `/var/www/mylawyer` (`current` و`backend` و`site` و`storage`)، وإعداد Nginx في `/etc/nginx/sites-available/mylawyer`، والنسخ الاحتياطية في `/root/mylawyer-backups`.
- **السجلات:** `journalctl -u mylawyer-backend` و`/var/log/nginx`.
- **الجدار الناري:** UFW مفتوح فيه 22 و80 و443 بس.
- **الدخول بكلمة المرور:** مقفول (`00-mylawyer.conf`)، والدخول بالمفتاح بس.

## أوامر قراءة آمنة
```bash
ssh mylawyer-vps 'systemctl is-active mylawyer-backend nginx postgresql'
ssh mylawyer-vps 'journalctl -u mylawyer-backend --since "-1h" -p err --no-pager'
ssh mylawyer-vps 'df -h / && free -m'
```

## قبل أي push أو رفع، اكتب لصاحب المشروع
1. الفرع الحالي والوجهة (الريموت والفرع).
2. الملفات اللي اتغيرت، وملخص التعديل.
3. الـ commits.
4. نتايج `flutter analyze` و`flutter test` و`npx tsc --noEmit` و`npm test`.
5. لو فيه migration: اتعملت نسخة احتياطية ولا لأ، وطريقة الرجوع.
6. المخاطر وتأثيرها على المستخدمين.

وبعدين استنى موافقته على العملية دي بالذات.

## سجل العمليات
أي عملية على الريبو البعيد أو السيرفر تتكتب في `docs/CHANGELOG.md` أو `docs/HANDOFF.md` في نفس اليوم.

| التاريخ | العملية | مين وافق |
|---|---|---|
| 2026-11-06 | قراءة بس من السيرفر (المنافذ والجدار الناري والخدمات وNginx والنسخ الاحتياطية)، من غير أي تعديل | مسموح من غير موافقة |
| 2026-11-06 | إضافة الاسم المختصر `mylawyer-vps` في `~/.ssh/config` على الجهاز المحلي | تعديل محلي |
| 2026-11-06 | إنشاء `.access/` ونسخ التوكن والمفتاح وبيانات اللوحة فيه، والتأكد إن السيرفر وGitHub بيشتغلوا منه (`ls-remote`، قراءة بس) | صاحب المشروع طلب كده |
