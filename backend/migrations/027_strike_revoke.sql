-- The admin can cancel a lawyer's strike, and a cancelled strike stops counting toward a suspension
ALTER TABLE lawyer_strikes
  ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS revoked_by UUID REFERENCES users(id) ON DELETE SET NULL;
