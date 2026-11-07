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
| `mylawyer_deploy` و`mylawyer_deploy.pub` | مفتاح SSH للسيرفر القديم (`mylawyer-vps`)، وصلاحيته لمستخدم Windows بس |
| `mylawyer_api` و`mylawyer_api.pub` | مفتاح SSH للسيرفر الجديد (`mylawyer-api`)، واتحط من لوحة Contabo وقت التسطيب |
| `known_hosts_mylawyer` | بصمة السيرفر |
| `ssh_config` | الاسمين المختصرين `mylawyer-vps` (القديم) و`mylawyer-api` (الجديد) بمسارات المجلد ده |
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
- **الرفع التلقائي:** `.github/workflows/deploy.yml` بيشتغل مع أي push على `main` يغيّر `backend/**`، على runner موجود على السيرفر الجديد (`mylawyer-api`). بيشغل `tsc` و`npm test` وبعدين `backend/deploy.sh`. يعني **push على `main` = رفع على الإنتاج**.

## السيرفر
- **الاسم المختصر:** `ssh mylawyer-vps` (الإعداد في `~/.ssh/config` على جهاز صاحب المشروع، بالمفتاح `~/.ssh/mylawyer_deploy`).
- **الدور:** إنتاج بس، ومفيش سيرفر تجريبي.
- **النظام:** Ubuntu 24.04، والخدمات: `mylawyer-backend` (systemd، على `127.0.0.1:4000`)، وPostgreSQL 16 (محلي)، وNginx 1.24، وDocker للخرائط (`mylawyer-osrm` و`mylawyer-tileserver`، محليين)، وPostfix وOpenDKIM.
- **المسارات:** التطبيق في `/var/www/mylawyer` (`current` و`backend` و`site` و`storage`)، وإعداد Nginx في `/etc/nginx/sites-available/mylawyer`، والنسخ الاحتياطية في `/root/mylawyer-backups`.
- **السجلات:** `journalctl -u mylawyer-backend` و`/var/log/nginx`.
- **الجدار الناري:** UFW مفتوح فيه 22 و80 و443 بس.
- **الدخول بكلمة المرور:** مقفول (`00-mylawyer.conf`)، والدخول بالمفتاح بس.

## السيرفر الجديد `mylawyer-api` (2026-11-07)
- **الدور:** الباك إند وقاعدة البيانات بعد النقل، والقديم يفضل للخرايط والطرق (قرار صاحب المشروع). لسه فاضي.
- **الدخول:** `ssh -F D:/KAREM/.access/ssh_config mylawyer-api`، بالمفتاح بس. الدخول بكلمة السر مقفول (`/etc/ssh/sshd_config.d/00-mylawyer.conf`)، وكلمة سر root عند صاحب المشروع ومش محفوظة هنا.
- **الحماية:** Ubuntu 24.04 متحدّث، وUFW مفتوح فيه 22 و80 و443 بس، وfail2ban على SSH، والتحديثات الأمنية تلقائية.
- **الموارد:** 6 معالجات، و12 جيجا رام، و100 جيجا.
- **المتسطّب (نفس نسخ القديم):** Node 20.20 وnpm 10.8، وPostgreSQL 16.15 (محلي بس)، وNginx 1.24، وcertbot 2.9، وSwap 4 جيجا، والتوقيت Europe/Berlin زي القديم.
- **الباك إند شغال هنا من 2026-11-07:** الكود من `origin/main` في `/var/www/mylawyer/backend` (`.env` وملف Firebase جنبه)، وخدمة `mylawyer-backend` بـ 5 workers، وقاعدة `mylawyer_prod` المحلية (اتنقلت من القديم كاملة)، والصور والملفات والموقع في `/var/www/mylawyer`. الطرق من `OSRM_URL=https://maps.my-lawyer.online/osrm`.
- **Nginx:** `/etc/nginx/sites-available/mylawyer` زي القديم، و`/map/v2` و`/osrm` بيتحوّلوا لـ `maps.my-lawyer.online` عشان نسخ التطبيق القديمة.
- **الإيميل:** Postfix محلي بس (`loopback-only`) وOpenDKIM بالمفتاح `mail` لـ `my-lawyer.online`، والإرسال من `noreply@my-lawyer.online`. سجلات MX وSPF وDKIM وDMARC في Hostinger، والـ PTR في Contabo.
- **https:** شهادات Let's Encrypt للعنوانين (2026-11-07) بالتحقق من `/var/www/letsencrypt`، وبتتجدد لوحدها (`certbot.timer`). قاعدة صلاحية محلية في `.claude/settings.local.json` بتسمح لـ Claude Code يشغّل certbot على السيرفرين بس.
- **الرفع التلقائي (2026-11-07):** runner اسمه `vps-mylawyer-api` على السيرفر الجديد في `/actions-runner-mylawyer` (خدمة `actions.runner.same7samy00-MyLawyer-.vps-mylawyer-api`)، والقديم `vps-mylawyer` اتشال من GitHub. يعني **push على `main` = رفع على السيرفر الجديد**. أول رفع عليه نجح (`95f0a80`).
- **DNS السيرفر:** `/etc/systemd/resolved.conf.d/mylawyer.conf` على 1.1.1.1 و8.8.8.8، لأن سيرفرات Contabo كانت بتعلّق.
- **الإيميل:** بيطلع على IPv4 بس (`inet_protocols = ipv4`)، لأن جوجل بيرفض IPv6 من غير اسم مأكّد. اتجرّب ووصل لـ Gmail.

## الدومين والسيرفرات (2026-11-07)
| العنوان | السيرفر | الشغل |
|---|---|---|
| `my-lawyer.online` و`www` | الجديد `45.13.232.30` | الباك إند واللوحة والموقع والإيميل |
| `maps.my-lawyer.online` | القديم `13.140.141.32` | صور الخريطة والطرق بس. الباك إند على القديم اتقفل |

الـ DNS في Hostinger (`dns-parking.com`)، والـ PTR في Contabo.

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
| 2026-11-07 | السيرفر القديم: مسح بقايا مشروع «aura-nest» (المستخدم وفولدراته وسجلاته وحزمة PHP) ومساحة Docker مش مستخدمة، ومسح كل النسخ الاحتياطية القديمة. المستخدم رقم 999 بتاع حاوية الخريطة بقى اسمه `mylawyer-maps`. النسخة اليومية التلقائية متسابة لحد النقل | صاحب المشروع («مسح») |
| 2026-11-07 | السيرفر الجديد: الدخول بالمفتاح، وقفل كلمة السر، وUFW وfail2ban وتحديث وإعادة تشغيل، وتسطيب Node وPostgreSQL وNginx وcertbot، وقاعدة فاضية | صاحب المشروع |
| 2026-11-07 | السيرفر القديم: رسم خريطة مصر كلها في كاش Nginx (حوالي 1.6 مليون مربع، زوم 8 لـ 15) بخدمة `mylawyer-map-seed` بأقصى سرعة، والسجل في `/var/log/mylawyer-map-seed.log` | صاحب المشروع |
| 2026-11-07 | السيرفر الجديد: تظبيط PostgreSQL وNginx وقفل TLS 1.0 و1.1، وإعادة تشغيل القاعدة والخادم (OPS-04) | صاحب المشروع («موافق») |
| 2026-11-06 | push على `main` (`966119a..9cb1eee`). الرفع التلقائي حدّث السيرفر، والصحة `UP`، ومفيش أخطاء، والنسخة الاحتياطية اتعملت | صاحب المشروع («ارفع») |
