-- A payment attempt that did not go through, so the client sees it in their payments page.
-- Successful payments stay in payments; this table only keeps the failed tries and why.
CREATE TABLE IF NOT EXISTS failed_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES service_orders(id) ON DELETE CASCADE,
    client_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    amount NUMERIC(10, 2) NOT NULL,
    method VARCHAR(20) NOT NULL CHECK (method IN ('WALLET', 'DIRECT')),
    reason VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_failed_payments_client ON failed_payments(client_id, created_at DESC);
