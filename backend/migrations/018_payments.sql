-- Every client payment gets its own number, so one payment can be reviewed later.
-- WALLET was paid from the client balance. DIRECT was confirmed without a payment gateway.
CREATE SEQUENCE IF NOT EXISTS ml_payment_seq START 100001;

CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference VARCHAR(32) NOT NULL UNIQUE DEFAULT 'ML-PAY-' || nextval('ml_payment_seq'),
    order_id UUID NOT NULL UNIQUE REFERENCES service_orders(id) ON DELETE CASCADE,
    client_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    amount NUMERIC(10, 2) NOT NULL,
    method VARCHAR(20) NOT NULL CHECK (method IN ('WALLET', 'DIRECT')),
    paid_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_payments_client ON payments(client_id, paid_at DESC);
CREATE INDEX IF NOT EXISTS idx_payments_paid_at ON payments(paid_at DESC);

-- Payments made before this table, oldest first
INSERT INTO payments (order_id, client_id, amount, method, paid_at)
SELECT o.id, o.client_id, o.price,
       CASE WHEN EXISTS (
         SELECT 1 FROM client_credits c WHERE c.order_id = o.id AND c.reason = 'سداد طلب من الرصيد'
       ) THEN 'WALLET' ELSE 'DIRECT' END,
       o.paid_at
FROM service_orders o
WHERE o.paid_at IS NOT NULL
ORDER BY o.paid_at, o.id;
