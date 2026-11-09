-- An available lawyer whose phone goes quiet gets silent wake-up pushes before being turned off (owner decision 2026-11-09):
-- 5 quiet minutes, a wake; 2 minutes later, another; 1 minute after that, off. Any location from the phone resets it.
ALTER TABLE lawyer_profiles ADD COLUMN IF NOT EXISTS wake_count SMALLINT NOT NULL DEFAULT 0;
ALTER TABLE lawyer_profiles ADD COLUMN IF NOT EXISTS last_wake_at TIMESTAMPTZ NULL;
