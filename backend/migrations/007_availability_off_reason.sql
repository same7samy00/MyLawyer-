-- Why a lawyer is unavailable, so a returning location restores only automatic hides
ALTER TABLE lawyer_profiles ADD COLUMN IF NOT EXISTS availability_off_reason VARCHAR(20);
ALTER TABLE lawyer_profiles DROP COLUMN IF EXISTS stale_reminder_sent;
