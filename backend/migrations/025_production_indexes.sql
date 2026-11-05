-- What the busiest screens ask for on every refresh
CREATE INDEX IF NOT EXISTS idx_orders_lawyer_open ON service_orders (lawyer_id) WHERE status IN ('PENDING', 'ACCEPTED', 'ACTIVE');
CREATE INDEX IF NOT EXISTS idx_orders_client_open ON service_orders (client_id) WHERE status IN ('PENDING', 'ACCEPTED', 'ACTIVE');
CREATE INDEX IF NOT EXISTS idx_orders_client_recent ON service_orders (client_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_lawyer_recent ON service_orders (lawyer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications (user_id) WHERE read_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_reviews_order ON reviews (order_id);
CREATE INDEX IF NOT EXISTS idx_request_offers_lawyer ON request_offers (lawyer_id);
