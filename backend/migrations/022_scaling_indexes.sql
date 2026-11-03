-- Reads and sweeps that scan a whole table today and get slower as data grows. Nothing here changes data.

-- Every notification tied to an order clears the stale ones of that order
CREATE INDEX IF NOT EXISTS idx_notifications_order ON notifications(order_id) WHERE order_id IS NOT NULL;

-- The lifecycle sweep looks for ended suspensions every few seconds
CREATE INDEX IF NOT EXISTS idx_users_suspended_until ON users(suspended_until) WHERE suspended_until IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_lawyer_profiles_suspended_until ON lawyer_profiles(suspended_until) WHERE suspended_until IS NOT NULL;

-- The review reminder only cares about recent finished orders, not all of them
CREATE INDEX IF NOT EXISTS idx_orders_review_reminder ON service_orders(completed_at)
    WHERE status = 'COMPLETED' AND review_reminder_sent = FALSE;
