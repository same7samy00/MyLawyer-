-- One "are you still available" reminder before an old pin leaves the map
ALTER TABLE lawyer_profiles ADD COLUMN IF NOT EXISTS stale_reminder_sent BOOLEAN NOT NULL DEFAULT FALSE;
