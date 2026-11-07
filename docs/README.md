# فهرس التوثيق

**اقرا على قد سؤالك بس.** كل جلسة بتبدأ بالملفات الأربعة اللي في الجزء الأول، والباقي يتقرا لما المهمة تحتاجه.

## كل جلسة (بالترتيب)
| الملف | ليه |
|---|---|
| `AGENTS.md` | القواعد الملزمة، والقسم 7 فيه بروتوكول البداية والتسليم |
| `docs/memory/CURRENT_STATUS.md` | الوضع الحالي: Git، وآخر حاجة، واللي جاي |
| `docs/memory/PENDING_TASKS.md` | المهام والمستني قرار |
| `docs/memory/DEVELOPMENT_LOG.md` | أول 5 سطور بس: مين اشتغل قبلك وعمل إيه |

## لما المهمة تحتاج
| لو سؤالك عن... | اقرا |
|---|---|
| قرار من صاحب المشروع (فلوس، خدمة، شكل، إطلاق) | `docs/DECISIONS.md` |
| المنتج والسيرفر وأماكن الملفات السرية والأجهزة | `docs/HANDOFF.md` |
| GitHub والسيرفر والرفع وبيانات الدخول | `docs/ACCESS.md` |
| المكونات وإزاي بتكلم بعض، ورحلة الطلب، والفلوس، والتحديث الحي | `docs/engineering/SYSTEM_MAP.md` |
| مسار معين في الخادم ومين بيستخدمه | `docs/engineering/API_REFERENCE.md`، والطلب والرد بالتفصيل في `docs/API_DOCUMENTATION.md` |
| مشكلة معروفة أو ثغرة | `docs/memory/KNOWN_ISSUES.md` (الملخص في أوله) |
| الأداء والكاش | `docs/engineering/PERFORMANCE.md` |
| التنضيف وإعادة التنظيم (كمّل من أول خطوة «لسه») | `docs/engineering/CLEANUP.md` |
| قاعدة البيانات | `docs/DATABASE_ARCHITECTURE.md`، و`backend/migrations` هو المرجع |
| طبقات التطبيق ولوحة التحكم | `docs/ARCHITECTURE.md` |
| الخريطة والموقع | `docs/GPS_SYSTEM.md` |
| السيرفرين والخدمات اللي عليهم | `docs/SERVER_ARCHITECTURE.md` |
| الرفع والرجوع | `docs/DEPLOYMENT.md` |
| النسخ الاحتياطية والاسترجاع | `docs/BACKUP_AND_RECOVERY.md` |
| الفروع والـ commits ونقط الرجوع | `docs/GIT_WORKFLOW.md` |
| تشغيل الاختبارات وإضافتها | `docs/TESTING.md` |
| الأسرار والدخول والحماية | `docs/SECURITY.md` |
| كل حاجة فين، وإضافة ميزة | `docs/PROJECT_STRUCTURE.md` |
| التقنيات ونسخها | `docs/TECH_STACK.md` |
| طريقة كتابة الكود والأدوات | `docs/ENGINEERING_STANDARDS.md` |
| الأدوات المتثبتة والمقترحة بالتكلفة | `docs/SERVER_TOOLS.md` |
| الفحص التلقائي والرفع وقرارات Docker | `docs/DEVOPS.md` |
| الصحة والسجلات والتنبيه | `docs/MONITORING.md` |
| أدوات الأمان وحالتها | `docs/SECURITY_TOOLS.md` |
| السعة وخطة التوسع | `docs/SCALABILITY.md` |
| اختبار الضغط ونتايجه | `docs/LOAD_TESTING.md` |
| القدرة وحدود التشغيل الآمن وقدرة السيرفرات | `docs/CAPACITY_PLANNING.md` |
| الجاهزية للإنتاج | `docs/PRODUCTION_READINESS.md` |
| ملاحظات الإصدارات | `docs/RELEASE_NOTES.md` |
| ذاكرة المشروع (الحالة والقواعد واللي جاي) | `docs/memory/README.md` |
| التشغيل والبناء محليًا | `docs/DEVELOPMENT_GUIDE.md` |
| إيه اللي اتغير ومتى | `docs/CHANGELOG.md` (الأحدث فوق)، والأقدم في `docs/CHANGELOG_ARCHIVE.md` |
| تقرير الفحوصات | `docs/engineering/VERIFICATION.md`، وآخر نتايج في `docs/memory/CURRENT_STATUS.md` |

## قواعد التوفير
- ما تقراش `CHANGELOG_ARCHIVE.md` ولا ملفات `docs/engineering/` كلها غير لو المهمة محتاجاها.
- الكود هو المرجع. لو التوثيق مختلف عن الكود، صدّق الكود وصلّح التوثيق في نفس الـ commit.
- اللي اتراجع واتوثق ما يتراجعش تاني: افحص بس الملفات اللي اتغيرت من آخر سطر في `DEVELOPMENT_LOG.md` (`git diff <commit>..HEAD --stat`).
