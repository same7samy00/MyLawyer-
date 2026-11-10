-- Two-step sign-in to the control page (2026-11-10): after the password, a 6-digit code by email.
-- Only its hash is kept, it works 10 minutes, 5 guesses, and once.
CREATE TABLE IF NOT EXISTS admin_login_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code_hash VARCHAR(64) NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  attempts SMALLINT NOT NULL DEFAULT 0,
  consumed_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_admin_login_codes_user ON admin_login_codes (user_id, created_at DESC);
