-- A client request goes to the nearest lawyers, who answer with their own price
CREATE TABLE IF NOT EXISTS service_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  service_title VARCHAR(255) NOT NULL,
  problem_type VARCHAR(100),
  problem_description TEXT NOT NULL,
  client_latitude NUMERIC NOT NULL,
  client_longitude NUMERIC NOT NULL,
  client_address TEXT,
  min_price NUMERIC NOT NULL,
  max_price NUMERIC NOT NULL,
  commission_percent NUMERIC NOT NULL,
  tax_percent NUMERIC NOT NULL,
  round INT NOT NULL DEFAULT 1,
  round_deadline TIMESTAMPTZ NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'OPEN',
  order_id UUID REFERENCES service_orders(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_service_requests_open ON service_requests (round_deadline) WHERE status = 'OPEN';
CREATE INDEX IF NOT EXISTS idx_service_requests_client ON service_requests (client_id, status);
CREATE INDEX IF NOT EXISTS idx_service_requests_order ON service_requests (order_id);

CREATE TABLE IF NOT EXISTS request_recipients (
  request_id UUID NOT NULL REFERENCES service_requests(id) ON DELETE CASCADE,
  lawyer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  round INT NOT NULL,
  distance_km NUMERIC NOT NULL,
  PRIMARY KEY (request_id, lawyer_id)
);
CREATE INDEX IF NOT EXISTS idx_request_recipients_lawyer ON request_recipients (lawyer_id);

CREATE TABLE IF NOT EXISTS request_offers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID NOT NULL REFERENCES service_requests(id) ON DELETE CASCADE,
  lawyer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  price NUMERIC NOT NULL,
  lawyer_amount NUMERIC NOT NULL,
  withdrawn_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (request_id, lawyer_id)
);
