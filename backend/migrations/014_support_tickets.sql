-- Support tickets replace the old complaints: one place for every problem a client or a lawyer sends.
-- UNDER_REVIEW until the first admin reply, then OPEN, and CLOSED only when an admin closes it.
CREATE SEQUENCE IF NOT EXISTS ml_ticket_seq;
SELECT setval('ml_ticket_seq', 100000);

CREATE TABLE IF NOT EXISTS support_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference VARCHAR(32) NOT NULL UNIQUE DEFAULT ('ML-TKT-' || nextval('ml_ticket_seq')),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    category VARCHAR(16) NOT NULL CHECK (category IN ('ORDER', 'MONEY', 'ACCOUNT', 'OTHER')),
    title VARCHAR(120) NOT NULL,
    order_id UUID NULL REFERENCES service_orders(id) ON DELETE SET NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'UNDER_REVIEW' CHECK (status IN ('UNDER_REVIEW', 'OPEN', 'CLOSED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_at TIMESTAMPTZ NULL,
    closed_by UUID NULL REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_support_tickets_user ON support_tickets(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON support_tickets(status, updated_at);
CREATE INDEX IF NOT EXISTS idx_support_tickets_order ON support_tickets(order_id);

-- USER is the sender, ADMIN a reply the sender sees, NOTE an internal note only the admins see
CREATE TABLE IF NOT EXISTS ticket_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
    author VARCHAR(8) NOT NULL CHECK (author IN ('USER', 'ADMIN', 'NOTE')),
    author_id UUID NULL REFERENCES users(id) ON DELETE SET NULL,
    body TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ticket_messages_ticket ON ticket_messages(ticket_id, created_at);

-- Images live in the private storage and are served only to the sender and the admins
CREATE TABLE IF NOT EXISTS ticket_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES ticket_messages(id) ON DELETE CASCADE,
    file_name VARCHAR(128) NOT NULL,
    mime VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ticket_attachments_message ON ticket_attachments(message_id);

-- Open complaints from the old system move into tickets, so no money stays frozen without a ticket
DO $$
DECLARE
    old RECORD;
    new_id UUID;
BEGIN
    FOR old IN
        SELECT client_id AS user_id, order_id, kind, reason, created_at FROM complaints WHERE status = 'OPEN'
        UNION ALL
        SELECT lawyer_id, order_id, kind, reason, created_at FROM lawyer_reports WHERE status = 'OPEN'
        ORDER BY created_at
    LOOP
        INSERT INTO support_tickets (user_id, category, title, order_id, created_at, updated_at)
        VALUES (old.user_id, CASE WHEN old.kind = 'MONEY' THEN 'MONEY' ELSE 'ORDER' END, 'شكوى على طلب', old.order_id, old.created_at, old.created_at)
        RETURNING id INTO new_id;
        INSERT INTO ticket_messages (ticket_id, author, author_id, body, created_at)
        VALUES (new_id, 'USER', old.user_id, COALESCE(NULLIF(old.reason, ''), 'شكوى على طلب'), old.created_at);
    END LOOP;
END $$;

UPDATE complaints SET status = 'RESOLVED', admin_note = 'نُقلت إلى تذكرة دعم فني', resolved_at = NOW() WHERE status = 'OPEN';
UPDATE lawyer_reports SET status = 'RESOLVED', admin_note = 'نُقلت إلى تذكرة دعم فني', resolved_at = NOW() WHERE status = 'OPEN';
