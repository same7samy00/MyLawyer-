# فهرس التوثيق

**اقرا على قد سؤالك بس.** كل جلسة بتبدأ بالملفات الأربعة اللي في الجزء الأول، والباقي يتقرا لما المهمة تحتاجه.

## كل جلسة (بالترتيب)
| الملف | ليه |
|---|---|
| `AGENTS.md` | القواعد الملزمة، والقسم 7 فيه بروتوكول البداية والتسليم |
| `docs/STATE.md` | الوضع الحالي: Git، وآخر حاجة، واللي جاي |
| `docs/TASKS.md` | المهام والمستني قرار |
| `docs/SESSIONS.md` | أول 5 سطور بس: مين اشتغل قبلك وعمل إيه |

## لما المهمة تحتاج
| لو سؤالك عن... | اقرا |
|---|---|
| قرار من صاحب المشروع (فلوس، خدمة، شكل، إطلاق) | `docs/DECISIONS.md` |
| المنتج والسيرفر وأماكن الملفات السرية والأجهزة | `docs/HANDOFF.md` |
| GitHub والسيرفر والرفع وبيانات الدخول | `docs/ACCESS.md` |
| المكونات وإزاي بتكلم بعض، ورحلة الطلب، والفلوس، والتحديث الحي | `docs/engineering/SYSTEM_MAP.md` |
| مسار معين في الخادم ومين بيستخدمه | `docs/engineering/API_REFERENCE.md`، والطلب والرد بالتفصيل في `docs/API_DOCUMENTATION.md` |
| مشكلة معروفة أو ثغرة | `docs/engineering/FINDINGS.md` (الملخص في أوله) |
| الأداء والكاش | `docs/engineering/PERFORMANCE.md` |
| قاعدة البيانات | `docs/DATABASE_ARCHITECTURE.md`، و`backend/migrations` هو المرجع |
| طبقات التطبيق ولوحة التحكم | `docs/ARCHITECTURE.md` |
| الخريطة والموقع | `docs/GPS_SYSTEM.md` و`docs/VPS_SERVER_AND_MAPS.md` |
| التشغيل والبناء محليًا | `docs/DEVELOPMENT_GUIDE.md` |
| إيه اللي اتغير ومتى | `docs/CHANGELOG.md` (الأحدث فوق)، والأقدم في `docs/CHANGELOG_ARCHIVE.md` |
| تقرير الفحوصات | `docs/engineering/VERIFICATION.md` و`docs/PRODUCTION_REPORT.md` |

## قواعد التوفير
- ما تقراش `CHANGELOG_ARCHIVE.md` ولا ملفات `docs/engineering/` كلها غير لو المهمة محتاجاها.
- الكود هو المرجع. لو التوثيق مختلف عن الكود، صدّق الكود وصلّح التوثيق في نفس الـ commit.
- اللي اتراجع واتوثق ما يتراجعش تاني: افحص بس الملفات اللي اتغيرت من آخر سطر في `SESSIONS.md` (`git diff <commit>..HEAD --stat`).
