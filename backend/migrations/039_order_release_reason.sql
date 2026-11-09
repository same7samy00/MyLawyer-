-- Why a chosen order closed before payment, so the orders page says it plainly (2026-11-09):
-- TAKEN: the lawyer was paid for by another client first; UNPAID: the client did not pay within 10 minutes.
ALTER TABLE service_orders ADD COLUMN IF NOT EXISTS release_reason VARCHAR(10) NULL;
