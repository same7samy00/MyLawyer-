-- The arrival deadline, the client's answer when the lawyer is late, and postponed tasks
ALTER TABLE service_orders
  ADD COLUMN IF NOT EXISTS arrival_deadline TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS arrival_reminder_sent BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS delay_notified_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS client_keeps_waiting BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS postponed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS postponed_until TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS postponed_reason TEXT;
