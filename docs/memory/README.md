# ذاكرة المشروع

الملفات دي هي **الذاكرة المرجعية** للمشروع: أي نموذج أو مطور يكمّل منها من آخر نقطة. الكود هو المرجع الأعلى؛ لو الذاكرة مختلفة عنه، اتحقق وصلّح الذاكرة.

## بداية أي جلسة (بالترتيب)
1. `AGENTS.md` (القواعد، والقسم 7 للبداية والتسليم).
2. [`CURRENT_STATUS.md`](CURRENT_STATUS.md): آخر حالة مؤكدة.
3. [`IMPORTANT_RULES.md`](IMPORTANT_RULES.md): الممنوعات والموافقات.
4. [`NEXT_STEPS.md`](NEXT_STEPS.md): اللي جاي.
5. أول 5 سطور من [`DEVELOPMENT_LOG.md`](DEVELOPMENT_LOG.md).
6. `git status` و`git log --oneline -5`، وقارنهم بـ `CURRENT_STATUS.md`.

## الملفات
| الملف | فيه إيه | بيتحدث إمتى |
|---|---|---|
| [`PROJECT_CONTEXT.md`](PROJECT_CONTEXT.md) | المشروع إيه، وخدماته، وأجزاؤه | لما المنتج أو البنية تتغير |
| [`CURRENT_STATUS.md`](CURRENT_STATUS.md) | الحالة المؤكدة، والفحوصات بنتيجتها | آخر كل جلسة غيّرت حاجة |
| [`IMPORTANT_RULES.md`](IMPORTANT_RULES.md) | القواعد اللي ما تتكسرش | لما قاعدة تتغير |
| [`NEXT_STEPS.md`](NEXT_STEPS.md) | اللي جاي بالترتيب | آخر كل جلسة |
| [`PENDING_TASKS.md`](PENDING_TASKS.md) | كل المهام المفتوحة والمستنية قرار | لما مهمة تتضاف أو تخلص |
| [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) | المشاكل بأرقام ثابتة ودليلها وحالتها | لما مشكلة تتلاقى أو تتحل |
| [`ARCHITECTURE_DECISIONS.md`](ARCHITECTURE_DECISIONS.md) | القرارات التقنية وأسبابها | مع كل قرار تقني |
| [`CHANGE_HISTORY.md`](CHANGE_HISTORY.md) | المحطات الكبيرة | مع كل تغيير كبير |
| [`DEVELOPMENT_LOG.md`](DEVELOPMENT_LOG.md) | سطر لكل جلسة: مين، وفين، وعمل إيه، والحالة | آخر كل جلسة |

قرارات المنتج في [`../DECISIONS.md`](../DECISIONS.md)، والتفاصيل الكاملة للتغييرات في [`../CHANGELOG.md`](../CHANGELOG.md).

## القواعد
- ما تمسحش سجلات قديمة. القرار الجديد بيتكتب ويقول إنه بيلغي القديم.
- افصل المؤكد («اتجرب») عن اللي ما اتجربش، واكتب التاريخ.
- ممنوع أي سر في أي ملف هنا.
