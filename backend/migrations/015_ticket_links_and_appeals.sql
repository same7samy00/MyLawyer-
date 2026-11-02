-- A notification can open the ticket it talks about
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS ticket_id UUID NULL REFERENCES support_tickets(id) ON DELETE SET NULL;

-- Appeals are now support tickets, so the open ones move into tickets
DO $$
DECLARE
    old RECORD;
    new_id UUID;
BEGIN
    FOR old IN SELECT lawyer_id, order_id, reason, created_at FROM order_appeals WHERE status = 'OPEN' ORDER BY created_at
    LOOP
        INSERT INTO support_tickets (user_id, category, title, order_id, created_at, updated_at)
        VALUES (old.lawyer_id, 'ORDER', 'اعتراض على انتهاء المهلة', old.order_id, old.created_at, old.created_at)
        RETURNING id INTO new_id;
        INSERT INTO ticket_messages (ticket_id, author, author_id, body, created_at)
        VALUES (new_id, 'USER', old.lawyer_id, COALESCE(NULLIF(old.reason, ''), 'اعتراض على انتهاء المهلة'), old.created_at);
    END LOOP;
END $$;

UPDATE order_appeals SET status = 'REJECTED', admin_note = 'نُقل إلى تذكرة دعم فني', resolved_at = NOW() WHERE status = 'OPEN';
