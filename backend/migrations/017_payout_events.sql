-- History of freezing and releasing order fees, for the money page of the control page
CREATE TABLE IF NOT EXISTS payout_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES service_orders(id) ON DELETE CASCADE,
    action VARCHAR(20) NOT NULL CHECK (action IN ('FREEZE', 'UNFREEZE', 'SETTLE')),
    amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    reason TEXT NOT NULL,
    created_by UUID NULL REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_payout_events_order ON payout_events(order_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payout_events_created ON payout_events(created_at DESC);
