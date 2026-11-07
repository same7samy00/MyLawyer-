-- Demo lawyer names rebuilt as «أ. first father family», the father always a man's name.
WITH lists AS (
  SELECT ARRAY['أحمد','محمد','محمود','مصطفى','إبراهيم','علي','حسن','حسين','خالد','عمرو','طارق','وليد','هشام','ياسر','كريم','سامح','عادل','أشرف','شريف','تامر','رامي','مينا','عبد الرحمن','عبد الله','يوسف','عمر','إسلام','سيد','نهى','منى','سارة','ريهام','دينا','هبة','مروة','إيمان','شيماء','نورهان','ياسمين','آية','ندى','مريم','فاطمة','سلمى','رانيا','أسماء'] AS firsts,
         ARRAY['أحمد','محمد','محمود','مصطفى','إبراهيم','علي','حسن','حسين','خالد','عمرو','طارق','وليد','هشام','ياسر','كريم','سامح','عادل','أشرف','شريف','تامر','عبد الرحمن','عبد الله','يوسف','عمر','سيد'] AS fathers,
         ARRAY['السيد','عبد العزيز','الشربيني','النجار','الجمال','عبد الحميد','الشافعي','البنا','المصري','عبد المنعم','الدسوقي','الطنطاوي','السمنودي','المحلاوي','عبد الفتاح','فرج','سليمان','حجازي','شلبي','عوض','زكي','منصور','رزق','الشامي','الخولي','بدوي','عيسى','غنيم','مرسي','حمدي','عطية','نصار','قنديل','الفقي','العشري','بركات'] AS families
), people AS (
  SELECT u.id, split_part(split_part(u.email, '-', 3), '@', 1)::int AS g
  FROM users u WHERE u.email LIKE 'demo-lawyer-%@demo.invalid'
), named AS (
  SELECT p.id, 'أ. ' || l.firsts[1 + (p.g * 7) % array_length(l.firsts, 1)] || ' ' ||
         l.fathers[1 + (p.g * 17) % array_length(l.fathers, 1)] || ' ' ||
         l.families[1 + (p.g * 11) % array_length(l.families, 1)] AS name
  FROM people p, lists l
)
UPDATE lawyer_profiles lp SET full_name = named.name FROM named WHERE lp.user_id = named.id;

UPDATE users u SET full_name = lp.full_name
FROM lawyer_profiles lp WHERE lp.user_id = u.id AND u.email LIKE 'demo-lawyer-%@demo.invalid';
