-- 5,000 available lawyers spread over about 40 km around Cairo, and 3,000 clients. Test copy only.
INSERT INTO users (phone, email, role, status, full_name, email_verified_at)
SELECT '0109' || lpad(g::text, 7, '0'), 'lt-lawyer-' || g || '@loadtest.invalid', 'lawyer', 'active', 'محامي تجريبي ' || g, NOW()
FROM generate_series(1, 5000) g;

INSERT INTO lawyer_profiles (user_id, full_name, syndicate_number, approval_status, is_available, urgent_status,
                             latitude, longitude, last_location_updated_at, last_active_at, rating, reviews_count, experience_years)
SELECT id, full_name, phone, 'approved', TRUE, 'APPROVED',
       30.0444 + (random() - 0.5) * 0.7, 31.2357 + (random() - 0.5) * 0.7, NOW(), NOW(),
       round((3 + random() * 2)::numeric, 2), (random() * 80)::int, (random() * 30)::int
FROM users WHERE email LIKE 'lt-lawyer-%';

INSERT INTO users (phone, email, role, status, full_name, email_verified_at)
SELECT '0118' || lpad(g::text, 7, '0'), 'lt-client-' || g || '@loadtest.invalid', 'client', 'active', 'موكل تجريبي ' || g, NOW()
FROM generate_series(1, 3000) g;

ANALYZE;
SELECT (SELECT COUNT(*) FROM lawyer_profiles WHERE urgent_status = 'APPROVED') AS lawyers,
       (SELECT COUNT(*) FROM users WHERE role = 'client') AS clients;
