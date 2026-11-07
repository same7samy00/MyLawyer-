-- Removes every demo lawyer (email @demo.invalid) and anything linked to them.
-- Also remove the keep-alive timer on the server: rm /etc/cron.d/mylawyer-demo-lawyers
BEGIN;
DELETE FROM request_offers WHERE lawyer_id IN (SELECT id FROM users WHERE email LIKE '%@demo.invalid');
DELETE FROM request_recipients WHERE lawyer_id IN (SELECT id FROM users WHERE email LIKE '%@demo.invalid');
DELETE FROM notifications WHERE user_id IN (SELECT id FROM users WHERE email LIKE '%@demo.invalid');
DELETE FROM change_log WHERE user_id IN (SELECT id FROM users WHERE email LIKE '%@demo.invalid');
DELETE FROM lawyer_profiles WHERE user_id IN (SELECT id FROM users WHERE email LIKE '%@demo.invalid');
DELETE FROM users WHERE email LIKE '%@demo.invalid';
COMMIT;
SELECT COUNT(*) AS demo_lawyers_left FROM users WHERE email LIKE '%@demo.invalid';
