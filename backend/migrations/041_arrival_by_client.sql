-- A lawyer who is with the client but can't press «وصلت» (weak GPS inside a building) asks the client to
-- confirm the arrival from their own phone (owner decision 2026-11-11).
ALTER TABLE service_orders
  ADD COLUMN IF NOT EXISTS arrival_asked_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS arrived_by_client BOOLEAN NOT NULL DEFAULT FALSE;
