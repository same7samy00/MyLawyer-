-- Transfers between any two accounts inside the app.
-- The money moves through the existing ledgers (client_credits and lawyer_adjustments),
-- and this table keeps the transfer itself for the daily limit and the admin review.
CREATE TABLE IF NOT EXISTS wallet_transfers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    recipient_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    amount NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (sender_id <> recipient_id)
);
CREATE INDEX IF NOT EXISTS idx_wallet_transfers_sender ON wallet_transfers(sender_id, created_at);
CREATE INDEX IF NOT EXISTS idx_wallet_transfers_recipient ON wallet_transfers(recipient_id, created_at);
