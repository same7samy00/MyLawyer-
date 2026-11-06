-- The newest point of each side on the way to the meeting, from payment until the lawyer arrives.
-- Only the latest point is kept, a route is never stored.
ALTER TABLE service_orders
    ADD COLUMN IF NOT EXISTS lawyer_live_latitude NUMERIC(10, 7),
    ADD COLUMN IF NOT EXISTS lawyer_live_longitude NUMERIC(10, 7),
    ADD COLUMN IF NOT EXISTS lawyer_live_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS client_live_latitude NUMERIC(10, 7),
    ADD COLUMN IF NOT EXISTS client_live_longitude NUMERIC(10, 7),
    ADD COLUMN IF NOT EXISTS client_live_at TIMESTAMPTZ;
