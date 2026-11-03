-- The system can now write order stages by itself, with no person behind them
ALTER TABLE order_status_logs ALTER COLUMN changed_by_user_id DROP NOT NULL;

-- Stages closed by a deadline were not written before, so they are added once from their deadlines
INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note, created_at)
SELECT o.id, NULL, 'PENDING', 'NO_RESPONSE', 'انتهت مهلة رد المحامي دون رد', COALESCE(o.response_deadline, o.updated_at)
FROM service_orders o
WHERE o.status = 'NO_RESPONSE'
  AND NOT EXISTS (SELECT 1 FROM order_status_logs l WHERE l.order_id = o.id AND l.new_status = 'NO_RESPONSE');

INSERT INTO order_status_logs (order_id, changed_by_user_id, old_status, new_status, note, created_at)
SELECT o.id, NULL, 'ACCEPTED', 'PAYMENT_EXPIRED', 'انتهت مهلة الدفع دون دفع', COALESCE(o.payment_deadline, o.updated_at)
FROM service_orders o
WHERE o.status = 'PAYMENT_EXPIRED'
  AND NOT EXISTS (SELECT 1 FROM order_status_logs l WHERE l.order_id = o.id AND l.new_status = 'PAYMENT_EXPIRED');

-- Who decided what on the control page
CREATE TABLE IF NOT EXISTS admin_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    action VARCHAR(30) NOT NULL,
    target_label TEXT NULL,
    target_user_id UUID NULL REFERENCES users(id) ON DELETE SET NULL,
    details TEXT NULL,
    created_by UUID NULL REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_admin_actions_created ON admin_actions(created_at DESC);
