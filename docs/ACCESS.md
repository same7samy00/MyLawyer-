# الوصول: الريبو، والسيرفرين، والحسابات

**آخر تحقق:** 2026-11-11، من الجهاز والسيرفرين. الملف ده ما فيهوش ولا هيبقى فيه أي كلمة سر أو مفتاح أو توكن: فيه **إيه موجود، وفين، وبيتستخدم في إيه** بس.

## 1. القاعدة الأساسية
| العملية | الحكم |
|---|---|
| تعديل الملفات محليًا، والاختبارات، والبناء، وcommit محلي | مسموح |
| قراية GitHub، وملفات السيرفر، والسجلات، وحالة الخدمات | مسموح |
| `git push`، أو tag، أو Pull Request | **لما صاحب المشروع يقول «ارفع» على الشغل ده بالذات** |
| أي تعديل على السيرفر، أو إعادة تشغيل، أو تغيير في بيانات الإنتاج | **موافقة صريحة كل مرة** |

- **ممنوع أي نموذج يطلب من صاحب المشروع توكن أو كلمة سر.** كل حاجة في `.access/`، ولو حاجة ناقصة اكتب إيه الناقص بالظبط.
- **ممنوع مسح أو تغيير أي مفتاح أو حساب أو صلاحية موجودة** من غير طلب صريح.
- قبل أي commit: `git status`، واتأكد إن مفيش ملف من `.access/` ظاهر. الريبو **عام**.

## 2. على الجهاز: مجلد `.access/` (Git بيتجاهله)
| الملف | لازمته |
|---|---|
| `ssh_config` | الاسمين المختصرين: `mylawyer-api` (الأساسي) و`mylawyer-vps` (التاني) |
| `mylawyer_api` و`.pub` | مفتاح SSH للسيرفر الأساسي |
| `mylawyer_deploy` و`.pub` | مفتاح SSH للسيرفر التاني |
| `known_hosts_mylawyer` | بصمة السيرفرين |
| `git-credentials` | توكن GitHub بصيغة `git credential store` |
| `cloudflare-token.txt` | السطر الأول توكن Cloudflare (تعديل DNS لدومين `my-lawyer.online` بس)، والتاني Zone ID |
| `admin-credentials.txt` | دخول لوحة التحكم |
| `test-accounts.txt` | الحسابات التجريبية |

**ملفات سرية تانية بره المجلد**، متجاهلة في Git، ولازم تفضل في مكانها لأن البناء بيقراها من هناك:
| الملف | لازمته |
|---|---|
| `android/mylawyer-release.jks` و`android/key.properties` | توقيع نسخة المتجر. **ضياعهم يمنع تحديث التطبيق**، فخد منهم نسخة بره الجهاز |
| `android/app/google-services.json` | إعداد Firebase في التطبيق |
| `backend/firebase-service-account.json` | مفتاح Firebase للخادم (محلي للتجربة) |
| `backend/.env` | إعدادات الخادم المحلية |
| `dart_defines.local.json` | فيه مفتاح خريطة قديم. التطبيق ما بيقراهوش دلوقتي (`KNOWN_ISSUES.md`) |

**الاستخدام من أي برنامج:**
```bash
ssh -F D:/KAREM/.access/ssh_config mylawyer-api
```
```bash
ssh -F D:/KAREM/.access/ssh_config mylawyer-vps
```
`git push` العادي شغال على جهاز صاحب المشروع (التوكن في Windows Credential Manager)، **وعشان كده لازم «ارفع» قبله**.

## 3. الريبو
- **المكان:** GitHub، `same7samy00/MyLawyer-`، والريموت `origin` (HTTPS). فرع واحد: `main`.
- **الرفع التلقائي:** `.github/workflows/deploy.yml` بيشتغل مع أي push على `main` يغيّر `backend/**`، على runner اسمه `vps-mylawyer-api` على السيرفر الأساسي (`/actions-runner-mylawyer`). يعني **push على `main` بتعديل في `backend/` = رفع على الإنتاج** (`DEPLOYMENT.md`).

## 4. على السيرفرين: إيه السر وفين
| السر | فين | مين بيستخدمه |
|---|---|---|
| إعدادات الخادم (القاعدة، وRedis، و`JWT_SECRET`، ومفتاح TomTom للطرق) | `/var/www/mylawyer/backend/.env` على السيرفرين (`600`، للمستخدم `www-data`) | الخادم. أسماء المتغيرات في `ENVIRONMENT.md` |
| مفتاح Firebase للخادم | `/var/www/mylawyer/backend/firebase-service-account.json` (`600`) | إشعارات الموبايل |
| مفتاح TomTom لصور الخريطة | `/etc/nginx/tomtom_map_key.conf` على الأساسي | خزنة الخريطة في Nginx |
| كلمة سر Redis | `/etc/redis/mylawyer.conf`، ونفسها في `REDIS_URL` | الخادم على السيرفرين |
| كلمات سر قاعدة البيانات (`mylawyer_user` و`replicator`) | جوه `DATABASE_URL`، وإعداد النسخة الحية على التاني | الخادم، والنسخة الحية |
| مفاتيح الخط الخاص (WireGuard) | `/etc/wireguard` على السيرفرين | الربط بين السيرفرين |
| توكن Cloudflare | `/etc/mylawyer/cloudflare.env` على **التاني بس** (`600`) | `take-over.sh` بيحوّل الدومين لوحده |
| شهادة https | `/etc/letsencrypt` على الأساسي، ونسخة على التاني | Nginx |
| مفتاح توقيع الإيميل (DKIM، اسمه `mail`) | OpenDKIM على الأساسي | الإيميل من `noreply@my-lawyer.online` |

## 5. مين يقدر يدخل السيرفرين (SSH بالمفتاح بس، وكلمة السر مقفولة)
| السيرفر | المفاتيح المسموحة (بالاسم) | لازمتها |
|---|---|---|
| الأساسي `mylawyer-api` | `mylawyer-new-server` (على `root` و`ubuntu`) | مفتاح `.access/mylawyer_api` اللي على الجهاز |
| التاني `mylawyer-vps` | `mylawyer-deploy` | مفتاح `.access/mylawyer_deploy` اللي على الجهاز |
| | `deploy` | الأساسي بيبعت بيه النسخة الجديدة للتاني (`/root/.ssh/mylawyer_second` على الأساسي) |
| | `api-backup-to-maps` | النسخة اليومية من الأساسي، ومقفول على فولدر النسخ بس (rrsync) |
| | `github-actions-mylawyer` | من أيام ما الرفع كان على السيرفر ده. **ما اتأكدتش إنه لسه مستخدم** (`KNOWN_ISSUES.md`) |

- حساب `pgbackrest` على التاني: نقل ملفات تاريخ القاعدة بس، ومن الخط الخاص بس.
- حساب `actions-runner` على الأساسي: بيشغّل الرفع التلقائي.
- كلمة سر `root` عند صاحب المشروع، ومش محفوظة في أي ملف.

## 6. حسابات بره السيرفرين (عند صاحب المشروع)
| الحساب | بيتحكم في إيه |
|---|---|
| GitHub (`same7samy00`) | الريبو والرفع التلقائي |
| Contabo | السيرفرين، والـ PTR بتاع الإيميل |
| Hostinger | تسجيل الدومين. الـ DNS اتنقل لـ Cloudflare يوم 2026-11-11 |
| Cloudflare | الـ DNS، والحماية، والكاش (`CLOUDFLARE.md`) |
| Firebase (مشروع `my-lawyer-51a6c`) | إشعارات الموبايل |
| TomTom | مفتاحين: الطرق، وصور الخريطة |
| Google Play Console | حساب المطوّر (شخصي، اتقبل 2026-11-11) والتطبيق (`GOOGLE_PLAY.md`) |
| Google Search Console | إثبات ملكية الموقع (العلامة في `backend/public/site/index.html`) |

## 7. صلاحيات Claude Code المحلية
`.claude/settings.local.json` (متجاهل في Git) بيسمح بتشغيل `certbot` على السيرفرين من غير سؤال. أي أمر تاني على السيرفر بيعدّي على فحص الصلاحيات.
