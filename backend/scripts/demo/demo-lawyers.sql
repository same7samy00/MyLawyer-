-- 1000 demo lawyers around El Mahalla El Kubra and Samanoud (Gharbia), available for the urgent service.
-- Marked by the email domain demo.invalid, so they can all be removed with demo-lawyers-remove.sql.
-- They cannot sign in (no password) and receive no push (no device). Production, owner request 2026-11-07.
WITH first_names AS (
  SELECT ARRAY['أحمد','محمد','محمود','مصطفى','إبراهيم','علي','حسن','حسين','خالد','عمرو','طارق','وليد','هشام','ياسر','كريم','سامح','عادل','أشرف','شريف','تامر','رامي','مينا','بيتر','جرجس','عبد الرحمن','عبد الله','يوسف','عمر','إسلام','سيد','نهى','منى','سارة','ريهام','دينا','هبة','مروة','إيمان','شيماء','نورهان','ياسمين','آية','ندى','مريم','فاطمة','سلمى','رانيا','أسماء'] AS v
), last_names AS (
  SELECT ARRAY['السيد','عبد العزيز','الشربيني','النجار','الجمال','عبد الحميد','الشافعي','البنا','المصري','عبد المنعم','الدسوقي','الطنطاوي','السمنودي','المحلاوي','عبد الفتاح','فرج','سليمان','حجازي','شلبي','عوض','زكي','منصور','رزق','الشامي','الخولي','بدوي','عيسى','غنيم','مرسي','حمدي','عطية','نصار','قنديل','الفقي','العشري','بركات'] AS v
), people AS (
  SELECT g,
    (SELECT v[1 + (g * 7) % array_length(v, 1)] FROM first_names) || ' ' ||
    (SELECT v[1 + (g * 13) % array_length(v, 1)] FROM first_names) || ' ' ||
    (SELECT v[1 + (g * 11) % array_length(v, 1)] FROM last_names) AS full_name,
    -- 70% around El Mahalla El Kubra, 30% around Samanoud
    CASE WHEN g % 10 < 7 THEN 30.9700 + (random() - 0.5) * 0.06 ELSE 30.9610 + (random() - 0.5) * 0.04 END AS lat,
    CASE WHEN g % 10 < 7 THEN 31.1670 + (random() - 0.5) * 0.06 ELSE 31.2410 + (random() - 0.5) * 0.04 END AS lon
  FROM generate_series(1, 1000) g
), new_users AS (
  INSERT INTO users (phone, email, role, status, full_name, email_verified_at)
  SELECT '0159' || lpad(g::text, 7, '0'), 'demo-lawyer-' || g || '@demo.invalid', 'lawyer', 'active', 'أ. ' || full_name, NOW()
  FROM people
  ON CONFLICT DO NOTHING
  RETURNING id, email, full_name
)
INSERT INTO lawyer_profiles (user_id, full_name, syndicate_number, approval_status, is_available, urgent_status,
                             latitude, longitude, last_location_updated_at, last_active_at, rating, reviews_count, experience_years)
SELECT nu.id, nu.full_name, 'D' || lpad(split_part(split_part(nu.email, '-', 3), '@', 1), 6, '0'), 'approved', TRUE, 'APPROVED',
       p.lat, p.lon, NOW(), NOW(),
       round((3.6 + random() * 1.4)::numeric, 2), (random() * 120)::int, 2 + (random() * 28)::int
FROM new_users nu
JOIN people p ON 'demo-lawyer-' || p.g || '@demo.invalid' = nu.email;

SELECT COUNT(*) AS demo_lawyers FROM users WHERE email LIKE '%@demo.invalid';
