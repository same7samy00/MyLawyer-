-- Simple settlement: two complaint kinds, account warnings, and admin balance changes

ALTER TABLE complaints ADD COLUMN IF NOT EXISTS kind VARCHAR(20) NOT NULL DEFAULT 'MONEY';
ALTER TABLE lawyer_reports ADD COLUMN IF NOT EXISTS kind VARCHAR(20) NOT NULL DEFAULT 'MONEY';
ALTER TABLE lawyer_reports ADD COLUMN IF NOT EXISTS resolution VARCHAR(30) NULL;

-- A temporary suspension ends by itself, an admin suspension has no end date
ALTER TABLE users ADD COLUMN IF NOT EXISTS suspended_until TIMESTAMPTZ NULL;

CREATE TABLE IF NOT EXISTS account_warnings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    order_id UUID NULL REFERENCES service_orders(id) ON DELETE SET NULL,
    reason TEXT NOT NULL,
    created_by UUID NULL REFERENCES users(id) ON DELETE SET NULL,
    revoked_at TIMESTAMPTZ NULL,
    revoked_by UUID NULL REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_account_warnings_user ON account_warnings(user_id, created_at);

-- Manual changes to a lawyer's balance, a negative sum is a debt paid from later fees
CREATE TABLE IF NOT EXISTS lawyer_adjustments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lawyer_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    order_id UUID NULL REFERENCES service_orders(id) ON DELETE SET NULL,
    amount NUMERIC(10, 2) NOT NULL,
    reason TEXT NOT NULL,
    created_by UUID NULL REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_lawyer_adjustments_lawyer ON lawyer_adjustments(lawyer_id, created_at);

ALTER TABLE client_credits ADD COLUMN IF NOT EXISTS created_by UUID NULL REFERENCES users(id) ON DELETE SET NULL;
