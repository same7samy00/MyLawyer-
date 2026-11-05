-- A request's notifications are one line that each new step replaces
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS request_id UUID REFERENCES service_requests(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_notifications_user_order ON notifications (user_id, order_id) WHERE order_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_notifications_user_request ON notifications (user_id, request_id) WHERE request_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications (created_at);
