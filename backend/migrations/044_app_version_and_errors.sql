-- The oldest app build the server still serves, so an important fix can be made to reach every phone, and the
-- crashes the app reports from people's phones (2026-11-11).
ALTER TABLE platform_settings
  ADD COLUMN IF NOT EXISTS min_app_build INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS app_update_url TEXT NULL;

CREATE TABLE IF NOT EXISTS app_errors (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NULL,
  app_build INT NULL,
  platform VARCHAR(20) NULL,
  message TEXT NOT NULL,
  stack TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_app_errors_created ON app_errors (created_at);
