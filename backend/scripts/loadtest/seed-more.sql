-- Up to 20,000 available lawyers and 20,000 clients. Test copy only.
INSERT INTO users (phone, email, role, status, full_name, email_verified_at)
SELECT '0109' || lpad(g::text, 7, '0'), 'lt-lawyer-' || g || '@loadtest.invalid', 'lawyer', 'active', 'محامي تجريبي ' || g, NOW()
FROM generate_series(5001, 20000) g;

INSERT INTO lawyer_profiles (user_id, full_name, syndicate_number, approval_status, is_available, urgent_status,
                             latitude, longitude, last_location_updated_at, last_active_at, rating, reviews_count, experience_years)
SELECT u.id, u.full_name, u.phone, 'approved', TRUE, 'APPROVED',
       30.0444 + (random() - 0.5) * 0.7, 31.2357 + (random() - 0.5) * 0.7, NOW(), NOW(),
       round((3 + random() * 2)::numeric, 2), (random() * 80)::int, (random() * 30)::int
FROM users u LEFT JOIN lawyer_profiles lp ON lp.user_id = u.id
WHERE u.email LIKE 'lt-lawyer-%' AND lp.id IS NULL;

INSERT INTO users (phone, email, role, status, full_name, email_verified_at)
SELECT '0118' || lpad(g::text, 7, '0'), 'lt-client-' || g || '@loadtest.invalid', 'client', 'active', 'موكل تجريبي ' || g, NOW()
FROM generate_series(3001, 20000) g;

-- The sweep hides a lawyer after 10 silent minutes, so the test keeps them fresh
UPDATE lawyer_profiles SET last_location_updated_at = NOW(), is_available = TRUE, availability_off_reason = NULL;
ANALYZE;
SELECT (SELECT COUNT(*) FROM lawyer_profiles WHERE urgent_status = 'APPROVED' AND is_available) AS lawyers,
       (SELECT COUNT(*) FROM users WHERE role = 'client') AS clients;
