-- The completion code is gone, so saved notifications that still talk about it get today's wording
UPDATE notifications SET body = 'ابدأ المهمة، ودوس «وصلت» لما تكون جنب الموكل، وبعدها أنهِ المهمة'
WHERE body = 'ابدأ المهمة، وفي الآخر هتحتاج كود الموكل لإنهائها';

UPDATE notifications SET body = 'قيّم المحامي، ولو فيه مشكلة دوس «عندك مشكلة؟» في الطلب'
WHERE body = 'قيّم المحامي، ولو فيه مشكلة قدم شكوى خلال 24 ساعة';

UPDATE notifications SET body = 'باقي 12 ساعة، سجّل وصولك عند الموكل وأنهِ المهمة قبل انتهاء المهلة'
WHERE body = 'باقي 12 ساعة، أنهِ المهمة بكود الموكل قبل انتهاء المهلة';

UPDATE notifications SET body = 'باقي 4 ساعات، لو المهلة خلصت من غير ما توصل للموكل المبلغ هيرجعله'
WHERE body = 'باقي 4 ساعات، لو المهلة خلصت الطلب هيتقفل من غير أتعاب';

UPDATE notifications SET body = 'أتعاب المهمة بقت متاحة في محفظتك'
WHERE body = 'تقدر تسحب أتعاب المهمة دلوقتي';

-- Old code warnings no longer mean anything to the client
DELETE FROM notifications WHERE body IN ('ثبت رفض إعطاء الكود بعد تنفيذ المهمة، والتكرار يوقف حسابك', 'تكرر رفض إعطاء كود إنهاء المهمة بعد تنفيذها');
